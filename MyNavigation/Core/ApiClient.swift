import Foundation

struct ApiException: Error, LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct AuthRequiredException: Error, LocalizedError {
    let pageUrl: String
    init(_ pageUrl: String) { self.pageUrl = pageUrl }
    var errorDescription: String? { "需要访问验证" }
}

/// 与安卓 ApiClient.kt 对齐的 REST 客户端（OkHttp → URLSession）：
///  - Cookie 共享（HTTPCookieStorage + WKWebsiteDataStore，登录态与 WebView 一致）
///  - X-User-Id / X-Auth-Token 头
///  - 自签名证书全信任（TrustAll 等价）
///  - SakuraFrp 防火墙拦截页静默表单验证
final class ApiClient {

    var userId: Int?
    var authToken: String?

    private let baseUrl: String
    private let session: URLSession

    init(baseUrl: String) {
        self.baseUrl = baseUrl
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "mynavigation_http")
        self.session = URLSession(configuration: config, delegate: TrustAllDelegate.shared, delegateQueue: nil)
    }

    // ====== URL 构造 ======

    private func buildUrl(_ path: String, _ params: [String: String] = [:]) throws -> URL {
        let trimmed = baseUrl.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { throw ApiException("请先在设置中填写 API 地址") }
        var components = URLComponents(string: trimmed)
        guard components != nil else { throw ApiException("API 地址格式不正确：\(trimmed)") }
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let base = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
        guard var url = URL(string: base + "/" + cleanPath) else {
            throw ApiException("API 地址格式不正确：\(trimmed)")
        }
        if !params.isEmpty {
            var uc = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            uc.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            url = uc.url!
        }
        _ = components
        return url
    }

    private func request(_ url: URL, method: String = "GET", body: Data? = nil, contentType: String? = nil, headers: [String: String] = [:]) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let uid = userId, uid > 0 { req.setValue("\(uid)", forHTTPHeaderField: "X-User-Id") }
        if let token = authToken, !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        return req
    }

    // ====== 防火墙（SakuraFrp 访问认证）后台静默通过 ======

    /// 后台自动完成拦截页验证：抓表单 → 填密码 → 提交，全程无界面。
    /// true = 已通过（或本来就没被拦）；false = 需要走界面兜底。
    func authenticate(pageUrl: String, password: String) async -> Bool {
        guard !password.isEmpty, let target = URL(string: pageUrl) else { return false }
        do {
            let (contentType, html) = try await fetchText(target)
            // 非 HTML（JSON 等）：没被拦，算通过
            if !contentType.lowercased().contains("text/html") && !html.lowercased().contains("<form") {
                return true
            }
            // 是 HTML 但不是防火墙验证页：不猜，交界面兜底
            guard looksLikeAuthPage(html) else { return false }
            guard let form = parseAuthForm(html: html, base: target, password: password) else { return false }

            let finalUrl: URL
            let method: String
            let bodyData: Data?
            let contentTypeHeader: String?
            if form.method == "post" {
                let encoded = form.fields
                    .map { "\(urlEncode($0.0))=\(urlEncode($0.1))" }
                    .joined(separator: "&")
                finalUrl = form.action
                method = "POST"
                bodyData = Data(encoded.utf8)
                contentTypeHeader = "application/x-www-form-urlencoded"
            } else {
                var uc = URLComponents(url: form.action, resolvingAgainstBaseURL: false)!
                uc.queryItems = (uc.queryItems ?? []) + form.fields.map { URLQueryItem(name: $0.0, value: $0.1) }
                finalUrl = uc.url ?? form.action
                method = "GET"
                bodyData = nil
                contentTypeHeader = nil
            }
            var req = request(finalUrl, method: method, body: bodyData, contentType: contentTypeHeader)
            req.setValue(pageUrl, forHTTPHeaderField: "Referer")
            let (_, afterData, _) = try await perform(req, raw: true)
            let after = String(data: afterData, encoding: .utf8) ?? ""
            // 提交后仍回验证页 = 密码错误 / 表单不对
            return !looksLikeAuthPage(after)
        } catch {
            return false
        }
    }

    /// 是否是“访问认证”拦截页（含密码框）
    private func looksLikeAuthPage(_ html: String) -> Bool {
        guard !html.isEmpty else { return false }
        let lower = html.lowercased()
        let hasPwd = lower.contains("type=\"password\"") || lower.contains("type=password")
        guard hasPwd else { return false }
        return html.contains("访问认证") || lower.contains("name=\"pw\"") || lower.contains("name=pw")
    }

    private struct AuthForm {
        let method: String
        let action: URL
        let fields: [(String, String)]
    }

    /// 解析拦截页里带密码框的那个 <form>，收集可提交字段（密码替换为配置值，勾上持久化）
    private func parseAuthForm(html: String, base: URL, password: String) -> AuthForm? {
        let formRegex = try? NSRegularExpression(pattern: "(?is)<form\\b([^>]*)>(.*?)</form>")
        let inputRegex = try? NSRegularExpression(pattern: "(?is)<input\\b([^>]*?)/?>")
        guard let formRegex, let inputRegex else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        for fm in formRegex.matches(in: html, range: range) {
            let bodyRange = fm.range(at: 2)
            guard bodyRange.location != NSNotFound, let bodyRangeSwift = Range(bodyRange, in: html) else { continue }
            let body = String(html[bodyRangeSwift])
            guard body.range(of: "(?is)type\\s*=\\s*[\"']?password", options: .regularExpression) != nil else { continue }
            let attrsRange = fm.range(at: 1)
            guard attrsRange.location != NSNotFound, let attrsSwift = Range(attrsRange, in: html) else { continue }
            let formAttrs = parseAttrs(String(html[attrsSwift]))
            let actionStr = formAttrs["action"]?.trimmingCharacters(in: .whitespaces)
            let action: URL
            if let a = actionStr, !a.isEmpty, let resolved = URL(string: a, relativeTo: base)?.absoluteURL {
                action = resolved
            } else {
                action = base
            }
            let method = (formAttrs["method"]?.lowercased() == "post") ? "post" : "get"
            var fields: [(String, String)] = []
            var hasPassword = false
            let inputRange = NSRange(body.startIndex..., in: body)
            for im in inputRegex.matches(in: body, range: inputRange) {
                let r = im.range(at: 1)
                guard r.location != NSNotFound, let rs = Range(r, in: body) else { continue }
                let a = parseAttrs(String(body[rs]))
                guard let name = a["name"], !name.isEmpty else { continue }
                let type = (a["type"] ?? "text").lowercased()
                switch type {
                case "password":
                    fields.append((name, password))
                    hasPassword = true
                case "checkbox", "radio":
                    let checked = body[rs].range(of: "(?is)\\bchecked\\b", options: .regularExpression) != nil
                    if checked || type == "checkbox" {
                        fields.append((name, a["value"] ?? "on"))
                    }
                case "submit", "button", "image", "file":
                    continue
                default:
                    fields.append((name, a["value"] ?? ""))
                }
            }
            if hasPassword {
                return AuthForm(method: method, action: action, fields: fields)
            }
        }
        return nil
    }

    /// 把 <form> / <input> 标签里的属性解析成小写 key -> value
    private func parseAttrs(_ tag: String) -> [String: String] {
        var out: [String: String] = [:]
        guard let re = try? NSRegularExpression(pattern: "(?is)([a-zA-Z_:][\\w:.-]*)\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))") else { return out }
        let range = NSRange(tag.startIndex..., in: tag)
        for m in re.matches(in: tag, range: range) {
            let keyRange = m.range(at: 1)
            guard keyRange.location != NSNotFound, let keySwift = Range(keyRange, in: tag) else { continue }
            let key = String(tag[keySwift]).lowercased()
            var raw = ""
            for gi in [3, 4, 5] {
                let r = m.range(at: gi)
                if r.location != NSNotFound, let rs = Range(r, in: tag) {
                    raw = String(tag[rs])
                    break
                }
            }
            if out[key] == nil {
                out[key] = raw.replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&quot;", with: "\"")
            }
        }
        return out
    }

    private func urlEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B") ?? s
    }

    // ====== 网站通用接口 ======

    /// POST /api/login —— 成功后 Session Cookie 自动进共享 Cookie 存储
    func login(username: String, password: String) async throws -> Json {
        let url = try buildUrl("api/login")
        let body = try JSONSerialization.data(withJSONObject: ["username": username, "password": password])
        return try await execute(request(url, method: "POST", body: body, contentType: "application/json; charset=utf-8"))
    }

    /// POST /api/logout
    func logout() async {
        guard let url = try? buildUrl("api/logout") else { return }
        let body = Data("{}".utf8)
        _ = try? await execute(request(url, method: "POST", body: body, contentType: "application/json; charset=utf-8"), requireSuccess: false)
    }

    /// POST /api/auth/refresh —— 旧 Token 换新 Token；失败一律返回 success=false，不抛鉴权异常
    func refreshToken() async -> Json {
        guard let url = try? buildUrl("api/auth/refresh") else {
            return ["success": false, "message": "网络错误"]
        }
        var req = request(url, method: "POST", body: Data("{}".utf8), contentType: "application/json; charset=utf-8")
        req.setValue(authToken ?? "", forHTTPHeaderField: "X-Auth-Token")
        do {
            let (resp, data) = try await rawPerform(req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.hasPrefix("{"), let j = JsonParse.object(text) { return j }
            return ["success": false, "message": "HTTP \(code)"]
        } catch {
            return ["success": false, "message": error.localizedDescription]
        }
    }

    /// GET /api/session —— 未登录时 success=false 也不抛错
    func session() async throws -> Json {
        try await rawGet("api/session")
    }

    /// 通用 GET（不强制 success 字段）
    func rawGet(_ path: String, _ params: [String: String] = [:]) async throws -> Json {
        let url = try buildUrl(path, params)
        let (resp, data, contentType) = try await perform(request(url), raw: false)
        _ = resp
        guard let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ApiException("服务器返回为空")
        }
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(url.absoluteString) }
        guard let json = JsonParse.object(text) else { throw AuthRequiredException(url.absoluteString) }
        return json
    }

    /// 通用 GET（要求 success=true）
    func getJson(_ path: String, _ params: [String: String] = [:]) async throws -> Json {
        try await rawGetOrThrow(path, params, requireSuccess: true)
    }

    private func rawGetOrThrow(_ path: String, _ params: [String: String], requireSuccess: Bool) async throws -> Json {
        let json = try await rawGet(path, params)
        if requireSuccess {
            guard json["success"] != nil else {
                throw ApiException("返回数据格式异常")
            }
            guard json.optBoolean("success") else {
                throw ApiException(json.optString("message", "请求失败"))
            }
        }
        return json
    }

    /// GET 返回原始文本（适配顶层数组 JSON）
    func getString(_ path: String, _ params: [String: String] = [:]) async throws -> String {
        let url = try buildUrl(path, params)
        let (_, data, contentType) = try await perform(request(url), raw: false)
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(url.absoluteString) }
        guard let text = String(data: data, encoding: .utf8) else { throw ApiException("响应解码失败") }
        return text
    }

    /// 通用 POST JSON body
    func postJson(_ path: String, _ json: Json) async throws -> Json {
        let url = try buildUrl(path)
        let body = try JSONSerialization.data(withJSONObject: json)
        return try await execute(request(url, method: "POST", body: body, contentType: "application/json; charset=utf-8"))
    }

    /// POST，参数放 query（签到 /api/check-in/do?userId=1）
    func postQuery(_ path: String, _ params: [String: String] = [:]) async throws -> Json {
        let url = try buildUrl(path, params)
        return try await execute(request(url, method: "POST", body: Data("{}".utf8), contentType: "application/json; charset=utf-8"))
    }

    /// PUT 任意 JSON 文本，返回原始响应文本
    func putText(_ path: String, _ jsonBody: String) async throws -> String {
        let url = try buildUrl(path)
        let (resp, data, contentType) = try await perform(
            request(url, method: "PUT", body: Data(jsonBody.utf8), contentType: "application/json; charset=utf-8"),
            raw: false
        )
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(url.absoluteString) }
        guard (200..<300).contains(resp.statusCode) else { throw ApiException("请求失败 HTTP \(resp.statusCode)") }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// POST 任意 JSON 文本，返回原始响应文本
    func postText(_ path: String, _ jsonBody: String) async throws -> String {
        let url = try buildUrl(path)
        let (resp, data, contentType) = try await perform(
            request(url, method: "POST", body: Data(jsonBody.utf8), contentType: "application/json; charset=utf-8"),
            raw: false
        )
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(url.absoluteString) }
        guard (200..<300).contains(resp.statusCode) else { throw ApiException("请求失败 HTTP \(resp.statusCode)") }
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// DELETE，返回是否 success（query 带归属参数）
    func delete(_ path: String, _ params: [String: String] = [:]) async throws -> Bool {
        let url = try buildUrl(path, params)
        let (resp, data, contentType) = try await perform(request(url, method: "DELETE"), raw: false)
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(url.absoluteString) }
        let text = String(data: data, encoding: .utf8) ?? ""
        if text.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            return JsonParse.object(text)?.optBoolean("success", true) ?? true
        }
        return (200..<300).contains(resp.statusCode)
    }

    /// 下载图片字节（保存到相册）
    func getBytes(_ absUrl: String) async throws -> Data {
        guard let url = URL(string: absUrl) else { throw ApiException("download failed: bad url") }
        let (resp, data) = try await rawPerform(request(url))
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else { throw ApiException("download failed HTTP \(code)") }
        return data
    }

    /// 上传图片（multipart），返回 JSON（/api/files/upload → {success,url,...}）
    func uploadImageJson(path: String, data: Data, filename: String = "upload.jpg") async throws -> Json {
        let url = try buildUrl(path)
        let boundary = "mynav\(UUID().uuidString)"
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".utf8))
        body.append(Data("Content-Type: image/*\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let (resp, respData, contentType) = try await perform(
            request(url, method: "POST", body: body, contentType: "multipart/form-data; boundary=\(boundary)"),
            raw: false
        )
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(url.absoluteString) }
        guard (200..<300).contains(resp.statusCode) else { throw ApiException("上传失败 HTTP \(resp.statusCode)") }
        let text = String(data: respData, encoding: .utf8) ?? ""
        guard let json = JsonParse.object(text) else { throw ApiException("上传返回格式异常") }
        guard json.optBoolean("success") else { throw ApiException(json.optString("message", "上传失败")) }
        return json
    }

    // ====== 底层 ======

    private func execute(_ req: URLRequest, requireSuccess: Bool = true) async throws -> Json {
        let (resp, data, contentType) = try await perform(req, raw: false)
        let pageUrl = req.url?.absoluteString ?? ""
        if resp.statusCode == 401 || resp.statusCode == 403 { throw AuthRequiredException(pageUrl) }
        guard (200..<300).contains(resp.statusCode) else { throw ApiException("请求失败 HTTP \(resp.statusCode)") }
        let text = String(data: data, encoding: .utf8) ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw ApiException("服务器返回为空") }
        if contentType.lowercased().contains("text/html") { throw AuthRequiredException(pageUrl) }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{"), let json = JsonParse.object(text) else { throw AuthRequiredException(pageUrl) }
        if requireSuccess {
            guard json["success"] != nil else { throw ApiException("返回数据格式异常：\(text.prefix(120))") }
            guard json.optBoolean("success") else { throw ApiException(json.optString("message", "请求失败")) }
        }
        return json
    }

    /// 发起请求；raw=false 时统一做 401/403、content-type 检查（与安卓 getString/putText 一致）
    private func perform(_ req: URLRequest, raw: Bool) async throws -> (HTTPURLResponse, Data, String) {
        let (resp, data) = try await rawPerform(req)
        guard let http = resp as? HTTPURLResponse else { throw ApiException("网络连接失败") }
        if !raw {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw AuthRequiredException(req.url?.absoluteString ?? "")
            }
        }
        let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
        return (http, data, contentType)
    }

    private func rawPerform(_ req: URLRequest) async throws -> (URLResponse, Data) {
        do {
            let (data, resp) = try await session.data(for: req)
            return (resp, data)
        } catch let e as AuthRequiredException {
            throw e
        } catch let e as ApiException {
            throw e
        } catch {
            throw ApiException("网络连接失败：\(error.localizedDescription)")
        }
    }

    private func fetchText(_ url: URL) async throws -> (contentType: String, text: String) {
        let (resp, data) = try await rawPerform(request(url))
        let contentType = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? ""
        return (contentType, String(data: data, encoding: .utf8) ?? "")
    }
}

/// Trust-all TLS（服务端自签名证书），与安卓 TrustAll.kt 对齐
final class TrustAllDelegate: NSObject, URLSessionDelegate {
    static let shared = TrustAllDelegate()
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
