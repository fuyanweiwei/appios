import UIKit
import SwiftUI
import UniformTypeIdentifiers
import Security

// ============================================================
// P4 分享接收 → 贴板（对照 Android MainActivity.handleShareText +
// AppViewModel.shareToBoard）。principal class（project.yml 已配
// $(PRODUCT_MODULE_NAME).ShareViewController），内部用 SwiftUI 展示状态。
// 扩展 target 不编译主 App 源码 → 需要的 Json 助手在 ShareJson.swift 复制了一份。
// ============================================================

private let appGroup = "group.com.weiwei.mynavigation"
private let defaultBaseUrl = "https://frp-box.com:40932"

/// 界面状态（保存中… / 已保存到贴板 / 未登录提示）
final class ShareModel: ObservableObject {
    @Published var message: String = "保存中…"
}

/// 服务端自签名证书全信任（与主 App TrustAllDelegate 一致）
final class ShareTrustDelegate: NSObject, URLSessionDelegate {
    static let shared = ShareTrustDelegate()
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

class ShareViewController: UIViewController {

    private let model = ShareModel()
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let host = UIHostingController(rootView: ShareView(model: model))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        extractText { [weak self] text in
            guard let self else { return }
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self.finish("没有可保存的内容")
                return
            }
            self.saveToBoard(text)
        }
    }

    // ====== 取分享来的文本（text/plain） ======

    private func extractText(completion: @escaping (String?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments, !attachments.isEmpty else {
            completion(nil)
            return
        }
        let hasText = attachments.contains { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
        let provider: NSItemProvider
        let typeId: String
        if hasText {
            provider = attachments.first { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }!
            typeId = UTType.plainText.identifier
        } else if let urlProvider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider = urlProvider
            typeId = UTType.url.identifier
        } else {
            completion(nil)
            return
        }
        provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
            DispatchQueue.main.async {
                if let s = item as? String {
                    completion(s)
                } else if let u = item as? URL {
                    completion(u.absoluteString)
                } else if let d = item as? Data {
                    completion(String(data: d, encoding: .utf8))
                } else {
                    completion(nil)
                }
            }
        }
    }

    // ====== POST api/board/save（对齐 Android shareToBoard） ======

    private func saveToBoard(_ text: String) {
        let defaults = UserDefaults(suiteName: appGroup) ?? .standard
        let userId = defaults.integer(forKey: "user_id")
        guard userId > 0 else {
            finish("登录后才能保存分享内容")
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            finish("没有可保存的内容")
            return
        }

        let rawBase = (defaults.string(forKey: "base_url") ?? "").trimmingCharacters(in: .whitespaces)
        let base = rawBase.isEmpty ? defaultBaseUrl : rawBase
        let root = base.hasSuffix("/") ? String(base.dropLast()) : base
        guard let url = URL(string: root + "/api/board/save") else {
            finish("保存失败：地址格式不正确")
            return
        }

        // title：前 40 字，换行转空格（与 Kotlin take(40).replace('\n',' ') 对齐）
        let title = String(trimmed.prefix(40)).replacingOccurrences(of: "\n", with: " ")
        let body: Json = [
            "userId": userId,
            "title": title,
            "content": trimmed,
            "scope": "private",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            finish("保存失败")
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = data
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("\(userId)", forHTTPHeaderField: "X-User-Id")
        let token = keychainToken()
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }
        req.timeoutInterval = 20

        let session = URLSession(configuration: .ephemeral,
                                 delegate: ShareTrustDelegate.shared,
                                 delegateQueue: nil)
        session.dataTask(with: req) { [weak self] respData, resp, _ in
            DispatchQueue.main.async {
                session.finishTasksAndInvalidate()
                guard let self, !self.finished else { return }
                let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                let text2 = respData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                guard (200..<300).contains(status), let json = JsonParse.object(text2) else {
                    self.finish(status == 0 ? "保存失败：网络错误" : "保存失败：HTTP \(status)")
                    return
                }
                if json.optBoolean("success") {
                    self.finish("已保存到贴板")
                } else {
                    // 对齐 Android：catch → "保存失败：<服务端 message>"
                    let msg = json.optString("message")
                    self.finish(msg.isEmpty ? "保存失败" : "保存失败：\(msg)")
                }
            }
        }.resume()
    }

    /// Keychain（service 与主 App SecureStore 一致）；小组件/扩展里可能读不到，失败只带 userId
    private func keychainToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.weiwei.mynavigation.secrets",
            kSecAttrAccount as String: "auth_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return ""
    }

    /// 展示结果 → 短暂停留 → 结束扩展
    private func finish(_ message: String) {
        guard !finished else { return }
        finished = true
        model.message = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            self?.extensionContext?.completeRequest()
        }
    }
}

/// 极简展示：居中胶囊提示（保存中… / 已保存到贴板 / 登录提示）
struct ShareView: View {
    @ObservedObject var model: ShareModel

    var body: some View {
        VStack {
            Spacer()
            Text(model.message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
