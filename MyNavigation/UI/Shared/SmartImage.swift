import SwiftUI
import UIKit

/// 三态图片（加载中 / 失败可重试 / 成功），对应安卓 SmartImage.kt
/// 走共享 URLSession（cookie 与 WebView 一致 + 信任自签名证书）
struct SmartImage: View {
    let url: String
    var contentMode: ContentMode = .fill
    @State private var retryKey = 0
    @State private var phase: Phase = .loading

    enum Phase { case loading, failed, ok }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.15))
                    ProgressView().controlSize(.small)
                }
                .task(id: url + "#\(retryKey)") { await load() }
            case .failed:
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.12))
                    VStack(spacing: 6) {
                        Image(systemName: "photo").font(.title2).foregroundStyle(.secondary)
                        Text("加载失败，点按重试")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    retryKey += 1
                    phase = .loading
                }
            case .ok:
                AsyncImage(url: URL(string: url)) { image in
                    image.resizable().aspectRatio(contentMode: contentMode)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.15))
                }
            }
        }
    }

    private func load() async {
        guard !url.isEmpty else { phase = .failed; return }
        // 先探活（复用 cookie / TLS 信任），再交给 AsyncImage 渲染
        guard let u = URL(string: url) else { phase = .failed; return }
        var req = URLRequest(url: u)
        req.timeoutInterval = 15
        req.cachePolicy = .returnCacheDataElseLoad
        do {
            let (_, resp) = try await TrustSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                phase = .ok
            } else {
                phase = .failed
            }
        } catch {
            phase = .failed
        }
    }
}

/// 图片专用共享会话（cookie 与主 ApiClient / WebView 共享，信任自签名证书）
enum TrustSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.urlCache = URLCache(memoryCapacity: 40 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, diskPath: "mynavigation_img")
        return URLSession(configuration: config, delegate: TrustAllDelegate.shared, delegateQueue: nil)
    }()
}
