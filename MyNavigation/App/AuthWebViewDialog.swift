import SwiftUI
import UIKit
import WebKit

// ====== 防火墙 / 拦截页验证（AuthWebViewScreen.kt 对齐）======

struct AuthWebViewDialog: View {
    let url: String
    let password: String
    let onRetry: () -> Void
    let onClose: () -> Void
    let onSuccess: () -> Void

    @Environment(\.palette) var palette
    @State private var progress: Double = 0
    @State private var pageLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // 顶栏：关闭 / 标题 / 重试
            HStack(spacing: 4) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.onPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")

                Text("访问验证")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.onPrimary)
                    .padding(.leading, 4)

                Spacer(minLength: 8)

                Button(action: onRetry) {
                    Text("重试")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(palette.onPrimary)
                        .frame(minWidth: 64, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .frame(height: 56)
            .background(palette.primary)

            Text("已自动填入密码并提交，通过后会自动继续；如未通过可手动提交后点右上角「重试」")
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if pageLoading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(palette.primary)
            }

            AuthWebViewRepresentable(
                url: url,
                password: password,
                onProgress: { progress = $0 },
                onLoading: { pageLoading = $0 },
                onSuccess: onSuccess
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}

// ====== WKWebView 包装 ======

private struct AuthWebViewRepresentable: UIViewRepresentable {
    let url: String
    let password: String
    let onProgress: (Double) -> Void
    let onLoading: (Bool) -> Void
    let onSuccess: () -> Void

    func makeCoordinator() -> AuthWebCoordinator {
        AuthWebCoordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // JS + DOM（localStorage / cookie 走 .default()，与站点登录态通用）
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        // 验证页可缩放（安卓端 builtInZoomControls）
        wv.scrollView.minimumZoomScale = 0.5
        wv.scrollView.maximumZoomScale = 3.0
        wv.scrollView.contentInsetAdjustmentBehavior = .never

        // 注入：探测是否存在密码框（HAS_PASSWORD_SCRIPT）+ 自动填密码并提交
        let controller = wv.configuration.userContentController
        controller.addUserScript(WKUserScript(
            source: AuthJS.hasPasswordProbe,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        if !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            controller.addUserScript(WKUserScript(
                source: AuthJS.fillAndSubmit(password),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            ))
        }

        context.coordinator.attach(wv)
        context.coordinator.loadedUrl = url
        if let u = URL(string: url) {
            wv.load(URLRequest(url: u))
        }
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard url != context.coordinator.loadedUrl else { return }
        context.coordinator.resetForNewUrl()
        context.coordinator.loadedUrl = url
        if let u = URL(string: url) {
            wv.load(URLRequest(url: u))
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: AuthWebCoordinator) {
        coordinator.dispose()
    }
}

// ====== 协调器：加载状态 + 自动填密码 + 成功探测 + 信任自签名证书 ======

private final class AuthWebCoordinator: NSObject, WKNavigationDelegate {
    var parent: AuthWebViewRepresentable
    /// 是否已自动提交过一次（防止密码错误时无限重提）
    private(set) var submitted = false
    /// 是否已确认离开验证页（验证通过，交给上层继续）
    private(set) var autoDone = false
    var loadedUrl: String?
    private var observations: [NSKeyValueObservation] = []

    init(_ parent: AuthWebViewRepresentable) {
        self.parent = parent
    }

    func attach(_ wv: WKWebView) {
        observations = [
            wv.observe(\.estimatedProgress) { [weak self] wv, _ in
                let p = wv.estimatedProgress
                DispatchQueue.main.async { self?.parent.onProgress(p) }
            },
            wv.observe(\.isLoading) { [weak self] wv, _ in
                let l = wv.isLoading
                DispatchQueue.main.async { self?.parent.onLoading(l) }
            },
        ]
    }

    func resetForNewUrl() {
        submitted = false
        autoDone = false
    }

    func dispose() {
        observations.forEach { $0.invalidate() }
        observations = []
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        parent.onLoading(true)
    }

    // 页面加载完成：先问当前页还有没有密码框：没有 = 已经过了验证页
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        parent.onLoading(false)
        parent.onProgress(1)
        guard !autoDone else { return }

        webView.evaluateJavaScript(AuthJS.hasPassword) { [weak self] result, _ in
            guard let self, !self.autoDone else { return }
            if !AuthWebCoordinator.truthy(result) {
                // 离开验证页 → 验证通过
                self.autoDone = true
                self.parent.onSuccess()
                return
            }
            let pw = self.parent.password.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !pw.isEmpty else { return }

            if !self.submitted {
                // 首次进入：用户脚本已填密码 + 勾选保持登录 + 自动提交；
                // 这里移除注入脚本，避免密码错误后无限重提，脚本没跑通则补一次
                self.submitted = true
                webView.configuration.userContentController.removeAllUserScripts()
                webView.evaluateJavaScript(AuthJS.submittedMarker) { marker, _ in
                    guard !AuthWebCoordinator.truthy(marker) else { return }
                    webView.evaluateJavaScript(AuthJS.fillAndSubmit(pw), completionHandler: nil)
                }
            } else {
                // 提交后仍在验证页（密码多半不对）：只补填，交给用户手动提交
                webView.evaluateJavaScript(AuthJS.fillOnly(pw), completionHandler: nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.parent.onLoading(false)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.parent.onLoading(false)
        }
    }

    // 站点是自签证书，必须放行（与 OkHttp 侧 TrustAll 一致）
    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private static func truthy(_ value: Any?) -> Bool {
        if let number = value as? NSNumber { return number.intValue != 0 }
        if let text = value as? String { return text == "1" || text.lowercased() == "true" }
        return false
    }
}

// ====== 注入脚本 ======

private enum AuthJS {
    /// 页面上是否还有密码框（0 = 已离开验证页）
    static let hasPassword =
        "(function(){return document.querySelectorAll('input[type=password]').length?1:0;})()"

    /// 文档结束时探测一次并缓存（WKUserScript 注入，与 HAS_PASSWORD_SCRIPT 同口径）
    static let hasPasswordProbe =
        "window.__mynav_has_pw=(function(){return document.querySelectorAll('input[type=password]').length?1:0;})();"

    /// 是否已自动提交过（window + sessionStorage 双保险）
    static let submittedMarker =
        "(function(){try{return (window.__mynav_sub||sessionStorage.__mynav_sub)?1:0;}catch(e){return window.__mynav_sub?1:0;}})()"

    /// 填密码 + 勾选“保持登录” + 自动提交表单（首次进入执行）
    static func fillAndSubmit(_ password: String) -> String {
        let pw = jsEscape(password)
        return "(function(){" +
            "try{if(window.sessionStorage&&sessionStorage.__mynav_sub){return 0;}}catch(e){}" +
            "function setVal(el,v){" +
            "var s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;" +
            "if(s){s.call(el,v);}else{el.value=v;}" +
            "el.dispatchEvent(new Event('input',{bubbles:true}));" +
            "el.dispatchEvent(new Event('change',{bubbles:true}));}" +
            "var ps=document.querySelectorAll('input[type=password]');if(!ps.length)return 0;" +
            "for(var i=0;i<ps.length;i++){if(!ps[i].value){setVal(ps[i],\"\(pw)\");}}" +
            "var boxes=document.querySelectorAll('input[type=checkbox]');" +
            "for(var j=0;j<boxes.length;j++){if(!boxes[j].checked){" +
            "var cs=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'checked').set;" +
            "if(cs){cs.call(boxes[j],true);}else{boxes[j].checked=true;}" +
            "boxes[j].dispatchEvent(new Event('change',{bubbles:true}));}}" +
            "function mark(){window.__mynav_sub=1;try{sessionStorage.__mynav_sub=1;}catch(e){}}" +
            "var el=ps[ps.length-1];" +
            "var form=el.form||(el.closest&&el.closest('form'));" +
            "if(form){try{if(typeof form.requestSubmit==='function'){form.requestSubmit();mark();return 1;}}catch(e){}" +
            "try{form.submit();mark();return 1;}catch(e){}}" +
            "var btn=document.querySelector('input[type=submit],button[type=submit],button');" +
            "if(btn){btn.click();mark();return 1;}" +
            "el.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',keyCode:13,which:13,bubbles:true}));" +
            "return 0;})()"
    }

    /// 只填密码（不提交），用于密码错误后回填让用户手动提交
    static func fillOnly(_ password: String) -> String {
        let pw = jsEscape(password)
        return "(function(){" +
            "function setVal(el,v){" +
            "var s=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value').set;" +
            "if(s){s.call(el,v);}else{el.value=v;}" +
            "el.dispatchEvent(new Event('input',{bubbles:true}));" +
            "el.dispatchEvent(new Event('change',{bubbles:true}));}" +
            "var ps=document.querySelectorAll('input[type=password]');" +
            "var n=0;for(var i=0;i<ps.length;i++){if(!ps[i].value){setVal(ps[i],\"\(pw)\");n++;}}" +
            "return n;})()"
    }

    static func jsEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
    }
}
