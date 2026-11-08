import SwiftUI
import UIKit
import UserNotifications

@main
@MainActor
struct MyNavigationApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var vm = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(vm)
                .onAppear {
                    ImageBase.baseUrl = Prefs.shared.baseUrl
                }
                .onOpenURL { url in
                    guard url.scheme == "mynavigation" else { return }
                    let target = url.host ?? url.pathComponents.dropFirst().first ?? ""
                    vm.navigateDeepLink(target)
                }
        }
    }
}

/// 冷启动打点 + 崩溃上报安装 + 使用统计（MainActivity 等价）；
/// 另负责：本地通知轮询调度、首次启动问通知权限、通知点击深链。
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        CrashReporter.install()
        UsageTracker.recordOpen()
        UsageTracker.maybeUpload()

        // P4 后台通知轮询：注册处理器 + 立即跑一轮（跑完自动排下一轮）
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        NotificationPoll.register()
        NotificationPoll.poll()

        // B0-5：首次启动询问通知权限（只问一次，拒绝不再骚扰）
        let prefs = Prefs()
        if !prefs.notifPermAsked {
            prefs.notifPermAsked = true
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
        return true
    }

    /// 前台也展示通知（Android 默认渠道 IMPORTANCE_DEFAULT 等价）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               willPresent notification: UNNotification,
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    /// 点通知 → 用 userInfo["deeplink"]（mynavigation://…）走自己的 scheme，
    /// 回调 RootView 的 onOpenURL → vm.navigateDeepLink（最简单可靠，不改 RootView）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                               didReceive response: UNNotificationResponse,
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let deeplink = userInfo["deeplink"] as? String,
           let url = URL(string: deeplink),
           url.scheme?.lowercased() == "mynavigation" {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
        completionHandler()
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        .all
    }
}

/// 路由根：登录页 / 主壳 + 防火墙验证页（AppRoot 等价）
struct RootView: View {
    @EnvironmentObject var vm: AppViewModel

    var body: some View {
        Group {
            switch vm.route {
            case .login:
                LoginScreen()
            case .main:
                MainShell()
            }
        }
        .environment(\.palette, AppPalette.of(
            dark: vm.themeMode == "dark" || (vm.themeMode == "system" && isSystemDark()),
            accentIndex: vm.accentIndex
        ))
        .overlay(alignment: .bottom) {
            if let msg = vm.message {
                ToastView(text: msg)
                    .onTapGesture { vm.clearMessage() }
                    .task(id: msg) {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        if vm.message == msg { vm.clearMessage() }
                    }
            }
        }
        .overlay {
            if let url = vm.authUrl {
                AuthWebViewDialog(
                    url: url,
                    password: vm.apiPassword,
                    onRetry: { vm.retryAfterAuth() },
                    onClose: { vm.closeAuthPage() },
                    onSuccess: { vm.retryAfterAuth() }
                )
            }
        }
    }

    private func isSystemDark() -> Bool {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark
    }
}

/// 轻量 Toast（Snackbar 等价，2.5 秒自动消失）
struct ToastView: View {
    let text: String
    @Environment(\.palette) var palette

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(palette.isDark ? Color.white : Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.82))
            )
            .padding(.bottom, 90)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            .transition(.opacity)
    }
}
