import SwiftUI
import UIKit
import WebKit

// ====== P3-2/P3-3 娱乐入口 + 游戏容器（GameScreens.kt 对齐）======

private struct GameEntry: Identifiable {
    let emoji: String
    let title: String
    let path: String
    let desc: String
    var id: String { path }
}

/// 网页端 entertain/ 下的游戏，一律进 WebView 容器（不重写）
private let GAMES: [GameEntry] = [
    GameEntry(emoji: "🀄", title: "麻将", path: "mahjong.html", desc: "和牌友搓一局"),
    GameEntry(emoji: "🗡️", title: "肉鸽", path: "rougelike.html", desc: "随机地牢闯关"),
    GameEntry(emoji: "🏠", title: "2D 家园", path: "home2d.html", desc: "经营自己的小屋"),
    GameEntry(emoji: "🎭", title: "生活模拟", path: "life_simulator.html", desc: "走一遍人生剧本"),
    GameEntry(emoji: "🧪", title: "元素推理", path: "element_reasoning.html", desc: "猜元素，冲榜单"),
    GameEntry(emoji: "🎰", title: "每日一抽", path: "daily_draw.html", desc: "看看今天手气"),
    GameEntry(emoji: "🎲", title: "小游戏", path: "myonegame.html", desc: "随手来一局"),
]

private func trimSlash(_ s: String) -> String {
    s.hasSuffix("/") ? String(s.dropLast()) : s
}

// ====== 游戏厅：手机友好的入口列表 ======

struct GameCenterScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    private var baseUrl: String { trimSlash(vm.baseUrl) }

    var body: some View {
        OverlayScaffold(title: "游戏厅") {
            VStack(alignment: .leading, spacing: 10) {
                Text("网页游戏，直接在 App 里玩（登录态与站点通用）")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .padding(.bottom, 4)

                ForEach(GAMES) { game in
                    Button {
                        vm.pushOverlay(
                            .gameContainer(
                                url: "\(baseUrl)/static/entertain/\(game.path)",
                                title: game.title
                            )
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text(game.emoji)
                                .font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(palette.primaryContainer)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(game.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(palette.onBackground)
                                Text(game.desc)
                                    .font(.system(size: 12))
                                    .foregroundStyle(palette.onSurfaceVariant)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.onSurfaceVariant)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(palette.surface)
                                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// ====== P3-2 游戏容器（手机定制外壳）======
// 顶栏（返回 / 标题 / 刷新 / 浏览器打开）+ 加载进度条 + 全屏内容；
// 站内链接在容器内继续加载，站外链接丢给系统浏览器；
// 返回键优先回网页历史，没历史了才退出容器。

/// 持有 WKWebView 引用（不进 SwiftUI 状态，避免在 makeUIView 里改 @State）
private final class WebViewHolder {
    weak var webView: WKWebView?
}

struct GameContainerScreen: View {
    let url: String
    let title: String

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var holder = WebViewHolder()
    @State private var progress: Double = 0
    @State private var loading = true
    @State private var pageTitle: String = ""

    private var baseUrl: String { trimSlash(vm.baseUrl) }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if loading {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(palette.primary)
            }
            GameWebView(
                url: url,
                baseUrl: baseUrl,
                holder: holder,
                onProgress: { progress = $0 },
                onLoadChange: { loading = $0 },
                onTitle: { pageTitle = $0 }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.background)
        .onAppear {
            if pageTitle.isEmpty { pageTitle = title }
            if URL(string: url) == nil {
                loading = false
                pageTitle = "页面加载失败"
            }
        }
    }

    // ---- 手机友好外壳：返回 / 标题 / 刷新 / 浏览器打开 ----

    private var navBar: some View {
        HStack(spacing: 2) {
            Button {
                // 返回优先网页历史
                if let wv = holder.webView, wv.canGoBack {
                    wv.goBack()
                } else {
                    vm.popOverlay()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.onBackground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(pageTitle.isEmpty ? title : pageTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(palette.onBackground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                holder.webView?.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                let current = holder.webView?.url ?? URL(string: url)
                if let current {
                    UIApplication.shared.open(current)
                }
            } label: {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .frame(height: 52)
        .background(palette.surface)
    }
}

// ====== WKWebView 包装 ======

private struct GameWebView: UIViewRepresentable {
    let url: String
    let baseUrl: String
    let holder: WebViewHolder
    let onProgress: (Double) -> Void
    let onLoadChange: (Bool) -> Void
    let onTitle: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // JS + DOM（localStorage / cookie 走 .default()，与站点登录态通用）
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.websiteDataStore = .default()
        // 允许自动播放
        config.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: .zero, configuration: config)
        // 关闭缩放
        wv.scrollView.minimumZoomScale = 1
        wv.scrollView.maximumZoomScale = 1
        wv.allowsBackForwardNavigationGestures = true
        wv.navigationDelegate = context.coordinator
        context.coordinator.observe(wv)

        holder.webView = wv
        if let u = URL(string: url) {
            wv.load(URLRequest(url: u))
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.dispose()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: GameWebView
        private var observations: [NSKeyValueObservation] = []

        init(_ parent: GameWebView) { self.parent = parent }

        func observe(_ wv: WKWebView) {
            observations = [
                wv.observe(\.estimatedProgress) { [weak self] wv, _ in
                    let p = wv.estimatedProgress
                    DispatchQueue.main.async { self?.parent.onProgress(p) }
                },
                wv.observe(\.isLoading) { [weak self] wv, _ in
                    let l = wv.isLoading
                    DispatchQueue.main.async { self?.parent.onLoadChange(l) }
                },
                wv.observe(\.title) { [weak self] wv, _ in
                    guard let t = wv.title else { return }
                    let title = t.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    DispatchQueue.main.async { self?.parent.onTitle(title) }
                },
            ]
        }

        func dispose() {
            observations.forEach { $0.invalidate() }
            observations = []
        }

        // 站内链接留在容器里，站外丢给 Safari
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            // 非主框架（iframe 等）一律放行
            if navigationAction.targetFrame?.isMainFrame == false {
                decisionHandler(.allow)
                return
            }
            let s = url.absoluteString
            if s.hasPrefix(parent.baseUrl) ||
                s.hasPrefix("about:") || s.hasPrefix("data:") || s.hasPrefix("blob:") ||
                s.hasPrefix("file:") {
                decisionHandler(.allow)
                return
            }
            if url.scheme == "http" || url.scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
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

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onLoadChange(false)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onLoadChange(false)
            }
        }
    }
}
