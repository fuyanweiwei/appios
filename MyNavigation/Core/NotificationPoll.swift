import Foundation
import BackgroundTasks
import UserNotifications

/// P4 推送（本地轮询）：周期拉取 /api/notification/dynamic/list，
/// 发现新未读 → 弹系统通知（对照 Android NotificationPollWorker）。
///
/// - `register()`：注册 BGTaskScheduler 处理器（AppDelegate 启动时调用）
/// - `schedule()`：排下一次 15 分钟后的刷新
/// - `poll()`：立即异步跑一轮，跑完自动排下一轮
/// 会话与防火墙逻辑复用 Core/ApiClient（Cookie 共享 + 拦截页自动处理）。
enum NotificationPoll {

    private static let taskId = "com.weiwei.mynavigation.notifpoll"
    /// channel 等价：categoryIdentifier（Android NotificationChannel "mynavigation_push"）
    private static let categoryId = "mynavigation_push"

    // ====== 调度 ======

    /// 注册后台任务处理器（didFinishLaunching 调用）
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil) { task in
            // 先排下一次（预算耗尽被杀也不会断链），再跑本轮
            schedule()
            Task.detached(priority: .utility) {
                await run()
                task.setTaskCompleted(success: true)
            }
        }
    }

    /// 排下一次刷新（最早 15 分钟后）
    static func schedule() {
        // 同 identifier 只允许一个待执行任务：先取消再提交，避免重复/冲突
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
        let req = BGAppRefreshTaskRequest(identifier: taskId)
        req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    /// 立即异步跑一轮，跑完自动排下一轮（AppDelegate 启动时调用）
    static func poll() {
        Task.detached(priority: .utility) {
            await run()
            schedule()
        }
    }

    // ====== 轮询 ======

    private static func run() async {
        let prefs = Prefs()
        let userId = prefs.userId
        guard userId > 0, !prefs.baseUrl.isEmpty else { return }

        let text: String
        do {
            let api = ApiClient(baseUrl: prefs.baseUrl)
            api.userId = userId
            api.authToken = prefs.authToken
            text = try await api.getString("api/notification/dynamic/list",
                                           ["userId": "\(userId)"])
        } catch {
            return // 静默失败，下个周期再试
        }

        guard let items = parseItems(text) else { return }

        // isRead=false 且 id > last_notif_id 的最大一条（与安卓循环语义一致）
        var maxId = prefs.lastNotifId
        var picked: Json?
        for o in items {
            if o.optBoolean("isRead", false) { continue }
            let id = o.optLong("id", 0)
            if id > maxId {
                maxId = id
                picked = o
            }
        }
        guard let picked, maxId > prefs.lastNotifId else { return }

        prefs.lastNotifId = maxId
        let name = picked.optString("name")
        notify(title: name.isEmpty ? "新通知" : name,
               body: picked.optString("message"),
               target: deepLinkFor(picked))
    }

    /// 顶层 JSONArray 或对象（data/list/... 数组）都兼容
    private static func parseItems(_ text: String) -> [Json]? {
        if let arr = JsonParse.array(text) { return arr.objects() }
        guard let obj = JsonParse.object(text) else { return nil }
        for key in ["data", "list", "records", "rows", "items"] {
            if let a = obj[key] as? [Any] { return a.objects() }
        }
        if let a = obj.values.first(where: { $0 is [Any] }) as? [Any] { return a.objects() }
        return nil
    }

    /// P4-5：按通知的 action/appType 推断该跳哪个页面（与安卓 deepLinkFor 一致）
    private static func deepLinkFor(_ o: Json) -> String {
        let action = o.optString("action")
        let appType = o.optString("appType")
        if action == "alarm" { return "mynavigation://board" }           // 私记闹钟 → 贴板
        switch appType {
        case "board": return "mynavigation://board"
        case "meme", "photo", "draw": return "mynavigation://media"      // 媒记（梗图/壁纸/绘画）
        case "novel": return "mynavigation://media/novel"                // 小说直达子栏
        case "daily", "column": return "mynavigation://home"
        case "": return "mynavigation://notifications"                   // 管理员广播等 → 通知中心
        default: return "mynavigation://features"
        }
    }

    // ====== 系统通知 ======

    private static func notify(title: String, body: String, target: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = categoryId
        content.sound = .default
        content.userInfo = ["deeplink": target]
        let req = UNNotificationRequest(identifier: "notifpoll_\(UUID().uuidString)",
                                        content: content,
                                        trigger: nil) // 立即投递
        UNUserNotificationCenter.current().add(req) { _ in }
    }
}
