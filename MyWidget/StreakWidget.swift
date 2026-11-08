import WidgetKit
import SwiftUI
import AppIntents
import Security
import UIKit

// ============================================================
// P4 桌面小组件：连签天数 + 一键签到（对照 Android
// MyNavWidgetProvider / WidgetCheckinReceiver / appwidget_view.xml）
// 数据全部从 App Group UserDefaults 读，键名与 Core/Prefs.swift 一致。
// ============================================================

private let appGroup = "group.com.weiwei.mynavigation"

enum WidgetPrefs {
    static let defaultBaseUrl = "https://frp-box.com:40932"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static var streak: Int { defaults.integer(forKey: "streak") }
    static var checkedInDate: String { defaults.string(forKey: "checked_in_date") ?? "" }
    static var userId: Int { defaults.integer(forKey: "user_id") }

    static var baseUrl: String {
        let v = defaults.string(forKey: "base_url") ?? ""
        return v.trimmingCharacters(in: .whitespaces).isEmpty ? defaultBaseUrl : v
    }

    static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// 小组件进程里读 Keychain 可能受限（无 entitlement 或被系统拒绝），
    /// 失败就返回空串 —— 请求只带 userId 也能签。
    static func authToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.weiwei.mynavigation.secrets",
            kSecAttrAccount as String: "auth_token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let text = String(data: data, encoding: .utf8) {
            return text
        }
        return ""
    }

    /// 签到成功后写回本地（主 App 与小组件共用同一份 App Group 数据）
    static func writeCheckIn(streak: Int) {
        defaults.set(today, forKey: "checked_in_date")
        defaults.set(streak, forKey: "streak")
    }
}

// ====== Timeline ======

struct StreakEntry: TimelineEntry {
    let date: Date
    let loggedIn: Bool
    let checkedToday: Bool
    let streak: Int

    /// 文案与 Android MyNavWidgetProvider.onUpdate 逐条对齐
    var streakText: String {
        if !loggedIn { return "登录后开始连签" }
        if checkedToday { return "今日已签到 · 连续 \(streak) 天" }
        if streak > 0 { return "已连签 \(streak) 天 · 今天还没签" }
        return "今天还没签到"
    }
}

struct StreakProvider: TimelineProvider {
    private func currentEntry() -> StreakEntry {
        let userId = WidgetPrefs.userId
        let checkedToday = userId != 0 && WidgetPrefs.checkedInDate == WidgetPrefs.today
        return StreakEntry(
            date: Date(),
            loggedIn: userId != 0,
            checkedToday: checkedToday,
            streak: WidgetPrefs.streak
        )
    }

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), loggedIn: true, checkedToday: true, streak: 12)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = currentEntry()
        // 每 30 分钟刷新一次（跨过零点后「今天还没签 / 已签到」会自己翻转）
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())
            ?? Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// ====== 一键签到 App Intent（iOS17，点按钮直接签，不打开 App） ======

struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "一键签到"
    static var description: IntentDescription? = IntentDescription("在薇薇导航一键签到，不用打开 App")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let userId = WidgetPrefs.userId
        let today = WidgetPrefs.today

        // 今天已签 → 只提示，不重复提交（对齐 WidgetCheckinReceiver）
        if WidgetPrefs.checkedInDate == today {
            return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: "今天已经签到过啦")))
        }
        guard userId > 0 else {
            return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: "先登录 App 才能签到")))
        }

        let trimmedBase = WidgetPrefs.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedBase.hasSuffix("/") ? String(trimmedBase.dropLast()) : trimmedBase
        guard let url = URL(string: base + "/api/check-in/do?userId=\(userId)") else {
            return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: "签到失败：地址格式不正确")))
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.httpBody = Data("{}".utf8)
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("\(userId)", forHTTPHeaderField: "X-User-Id")
        req.timeoutInterval = 20
        let token = WidgetPrefs.authToken()
        if !token.isEmpty { req.setValue(token, forHTTPHeaderField: "X-Auth-Token") }

        let session = URLSession(configuration: .ephemeral,
                                 delegate: WidgetTrustDelegate.shared,
                                 delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (data, resp) = try await session.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: "签到失败：HTTP \(code)")))
            }
            let success = (json["success"] as? Bool) ?? ((json["success"] as? NSNumber)?.boolValue ?? true)
            guard success else {
                let msg = (json["message"] as? String) ?? "签到失败"
                return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: msg)))
            }
            let current = WidgetPrefs.streak
            let streak = intValue(json["streak"]) ?? current
            WidgetPrefs.writeCheckIn(streak: streak)
            // 刷新小组件显示（按钮变「已签到 ✓」，文案变「今日已签到」）
            WidgetCenter.shared.reloadAllTimelines()

            var msg = "签到成功：连续 \(streak) 天"
            if let coins = intValue(json["coinsReward"]), coins > 0 { msg += "，+\(coins) 金币" }
            return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: msg)))
        } catch {
            return .result(dialog: IntentDialog(LocalizedStringResource(stringLiteral: "签到失败：网络错误")))
        }
    }

    private func intValue(_ v: Any?) -> Int? {
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s) { return i }
        return nil
    }
}

/// 服务端自签名证书全信任（与主 App TrustAllDelegate 一致）
private final class WidgetTrustDelegate: NSObject, URLSessionDelegate {
    static let shared = WidgetTrustDelegate()
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

// ====== UI（appwidget_view.xml 的横向布局：标题+连签文案 | 签到按钮） ======

struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) private var family

    private var openAppLink: some View {
        Link(destination: URL(string: "mynavigation://home")!) {
            VStack(alignment: .leading, spacing: 4) {
                Text("薇薇导航")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text(entry.streakText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var checkInButton: some View {
        if entry.loggedIn {
            Button(intent: CheckInIntent()) {
                Text(entry.checkedToday ? "已签到 ✓" : "签到")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        } else {
            Link(destination: URL(string: "mynavigation://home")!) {
                Text("去登录")
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.accentColor.opacity(0.9)))
                    .foregroundStyle(.white)
            }
        }
    }

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                openAppLink
                Spacer(minLength: 0)
                checkInButton
            }
        default:
            HStack(spacing: 12) {
                openAppLink
                checkInButton
            }
        }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StreakWidget", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(.secondarySystemBackground)
                }
        }
        .configurationDisplayName("连签签到")
        .description("显示连签天数，可一键签到。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
