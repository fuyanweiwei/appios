import Foundation

/// Q-11 使用统计（与安卓 UsageTracker.kt 对齐）：
///  1) record —— 本地按「日期 → 事件 → 次数」累加
///  2) maybeUpload —— 进 App 时：待推送 ≥20 条 或 距上次 ≥24h → 批量 POST api/app-usage/track
///  3) localStats —— 本地统计（使用统计页）
enum UsageTracker {

    static let OPEN = "open"
    static let CHECK_IN = "check_in"
    static let DAILY_POST = "daily_post"
    static let BOARD_POST = "board_post"
    static let MEDIA_VIEW = "media_view"
    static let FEATURE_ADD = "feature_add"
    static let GAME_OPEN = "game_open"
    static let NOVEL_READ = "novel_read"

    /// 事件中文名（与网站统计页同口径）
    static let LABELS: [String: String] = [
        OPEN: "打开 App",
        CHECK_IN: "签到",
        DAILY_POST: "发日常",
        BOARD_POST: "发贴板",
        MEDIA_VIEW: "看图",
        FEATURE_ADD: "新增记录",
        GAME_OPEN: "玩游戏",
        NOVEL_READ: "读小说",
    ]

    private static let PUSH_BATCH = 20
    private static let PUSH_INTERVAL_MS: Double = 24 * 60 * 60 * 1000

    private static let defaults = UserDefaults(suiteName: Prefs.appGroup) ?? .standard
    private static let K_STATS = "usage_stats"
    private static let K_PENDING = "usage_pending"
    private static let K_LAST_PUSH = "usage_last_push"

    private static var openedRecorded = false
    private static let lock = NSLock()

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    static func record(_ event: String) {
        guard !event.isEmpty else { return }
        let date = today()
        lock.lock()
        var stats = decode(defaults.string(forKey: K_STATS))
        var pending = decode(defaults.string(forKey: K_PENDING))
        bump(&stats, date, event)
        bump(&pending, date, event)
        defaults.set(encode(stats), forKey: K_STATS)
        defaults.set(encode(pending), forKey: K_PENDING)
        lock.unlock()
    }

    static func recordOpen() {
        lock.lock()
        let already = openedRecorded
        openedRecorded = true
        lock.unlock()
        if !already { record(OPEN) }
    }

    static func pendingTotal() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return decode(defaults.string(forKey: K_PENDING)).values.reduce(0) { $0 + $1.values.reduce(0, +) }
    }

    /// 本地全量统计：日期倒序 → 事件 → 次数
    static func localStats() -> [String: [String: Int]] {
        lock.lock()
        defer { lock.unlock() }
        let raw = decode(defaults.string(forKey: K_STATS))
        let keys = raw.keys.sorted(by: >)
        var out: [String: [String: Int]] = [:]
        for k in keys { out[k] = raw[k] }
        return out
    }

    /// 进 App 时调一次：攒够 20 条或超 24 小时就后台批量上报
    static func maybeUpload() {
        lock.lock()
        let pending = decode(defaults.string(forKey: K_PENDING))
        let total = pending.values.reduce(0) { $0 + $1.values.reduce(0, +) }
        let last = defaults.double(forKey: K_LAST_PUSH)
        let now = Date().timeIntervalSince1970 * 1000
        var snapshot: [String: [String: Int]]?
        var pushAt = 0.0
        if total > 0 && (total >= PUSH_BATCH || now - last >= PUSH_INTERVAL_MS) {
            snapshot = pending
            pushAt = now
        }
        lock.unlock()
        guard let batch = snapshot else { return }
        Task.detached {
            let prefs = Prefs.shared
            guard prefs.userId != 0, !prefs.baseUrl.isEmpty else { return }
            let api = ApiClient(baseUrl: prefs.baseUrl)
            api.userId = prefs.userId
            api.authToken = prefs.authToken.isEmpty ? nil : prefs.authToken
            var stats: [Json] = []
            for (date, events) in batch {
                for (event, count) in events {
                    stats.append(["date": date, "event": event, "count": count])
                }
            }
            let body: Json = ["userId": prefs.userId, "stats": stats]
            if let json = try? await api.postJson("api/app-usage/track", body), json.optBoolean("success") {
                commitPush(batch, pushAt)
            }
        }
    }

    private static func commitPush(_ snapshot: [String: [String: Int]], _ pushAt: Double) {
        lock.lock()
        var cur = decode(defaults.string(forKey: K_PENDING))
        for (date, events) in snapshot {
            guard var row = cur[date] else { continue }
            for (event, count) in events {
                let left = (row[event] ?? 0) - count
                if left > 0 { row[event] = left } else { row.removeValue(forKey: event) }
            }
            if row.isEmpty { cur.removeValue(forKey: date) } else { cur[date] = row }
        }
        defaults.set(encode(cur), forKey: K_PENDING)
        defaults.set(pushAt, forKey: K_LAST_PUSH)
        lock.unlock()
    }

    private static func bump(_ map: inout [String: [String: Int]], _ date: String, _ event: String) {
        var row = map[date] ?? [:]
        row[event] = (row[event] ?? 0) + 1
        map[date] = row
    }

    private static func decode(_ raw: String?) -> [String: [String: Int]] {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: [String: Int]] = [:]
        for (date, value) in obj {
            guard let row = value as? [String: Any] else { continue }
            var inner: [String: Int] = [:]
            for (event, count) in row {
                if let n = count as? Int { inner[event] = n }
                else if let n = count as? NSNumber { inner[event] = n.intValue }
            }
            if !inner.isEmpty { out[date] = inner }
        }
        return out
    }

    private static func encode(_ map: [String: [String: Int]]) -> String {
        guard JSONSerialization.isValidJSONObject(map),
              let data = try? JSONSerialization.data(withJSONObject: map),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}
