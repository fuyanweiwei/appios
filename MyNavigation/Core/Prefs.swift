import Foundation

/// 与安卓 Prefs.kt 对齐的偏好存取。
/// 敏感项（authToken / apiPassword）→ Keychain；其余 → UserDefaults（App Group 共享给小组件）。
final class Prefs {

    static let shared = Prefs()

    /// 小组件 / 分享扩展与主 App 共享
    static let appGroup = "group.com.weiwei.mynavigation"

    private let defaults: UserDefaults
    private let secrets: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: Prefs.appGroup) ?? .standard
        secrets = .standard
    }

    static let DEFAULT_BASE_URL = "https://frp-box.com:40932"

    private enum K {
        static let userId = "user_id"
        static let baseUrl = "base_url"
        static let username = "username"
        static let streak = "streak"
        static let themeMode = "theme_mode"
        static let accentIndex = "accent_index"
        static let lastNotifId = "last_notif_id"
        static let notifPermAsked = "notif_perm_asked"
        static let tokenExpiresAt = "token_expires_at"
        static let readerFont = "reader_font_scale"
        static let readerNight = "reader_night"
        static let readerProgressPrefix = "reader_progress_"
        static let checkedInDate = "checked_in_date"
        static let coldStartMs = "last_cold_start_ms"
        // Keychain 里的键
        static let authToken = "auth_token"
        static let apiPassword = "api_password"
    }

    var userId: Int {
        get { defaults.integer(forKey: K.userId) }
        set { defaults.set(newValue, forKey: K.userId) }
    }

    var baseUrl: String {
        get { defaults.string(forKey: K.baseUrl) ?? Self.DEFAULT_BASE_URL }
        set { defaults.set(newValue.trimmingCharacters(in: .whitespaces), forKey: K.baseUrl) }
    }

    /// 防火墙密码（安卓端由 local.properties → BuildConfig 注入默认值）
    var apiPassword: String {
        get {
            let v = SecureStore.secret(K.apiPassword)
            if !v.isEmpty { return v }
            return secrets.string(forKey: "firewallPassword") ?? ""
        }
        set { SecureStore.setSecret(newValue, for: K.apiPassword) }
    }

    var username: String {
        get { defaults.string(forKey: K.username) ?? "" }
        set { defaults.set(newValue, forKey: K.username) }
    }

    var streak: Int {
        get { defaults.integer(forKey: K.streak) }
        set { defaults.set(newValue, forKey: K.streak) }
    }

    /// 主题：system / light / dark
    var themeMode: String {
        get { defaults.string(forKey: K.themeMode) ?? "system" }
        set { defaults.set(newValue, forKey: K.themeMode) }
    }

    /// 主题色索引（AccentPresets）
    var accentIndex: Int {
        get { defaults.integer(forKey: K.accentIndex) }
        set { defaults.set(newValue, forKey: K.accentIndex) }
    }

    /// 推送：上次已通知的动态 id
    var lastNotifId: Int {
        get { defaults.integer(forKey: K.lastNotifId) }
        set { defaults.set(newValue, forKey: K.lastNotifId) }
    }

    /// 通知权限是否已询问过（只问一次）
    var notifPermAsked: Bool {
        get { defaults.bool(forKey: K.notifPermAsked) }
        set { defaults.set(newValue, forKey: K.notifPermAsked) }
    }

    /// 登录签发的 30 天 Token，随请求带 X-Auth-Token 头
    var authToken: String {
        get { SecureStore.secret(K.authToken) }
        set { SecureStore.setSecret(newValue, for: K.authToken) }
    }

    /// Token 过期时间（毫秒时间戳），到期前自动静默续签
    var tokenExpiresAt: Int {
        get { defaults.integer(forKey: K.tokenExpiresAt) }
        set { defaults.set(newValue, forKey: K.tokenExpiresAt) }
    }

    /// 字号倍数（0.8 ~ 2.0）
    var readerFontScale: Double {
        get { min(max(defaults.double(forKey: K.readerFont) == 0 ? 1.0 : defaults.double(forKey: K.readerFont), 0.8), 2.0) }
        set { defaults.set(min(max(newValue, 0.8), 2.0), forKey: K.readerFont) }
    }

    /// 阅读器内夜间模式（只影响阅读页）
    var readerNight: Bool {
        get { defaults.bool(forKey: K.readerNight) }
        set { defaults.set(newValue, forKey: K.readerNight) }
    }

    /// 最近一次冷启动耗时（ms）
    var lastColdStartMs: Int {
        get { defaults.integer(forKey: K.coldStartMs) }
        set { defaults.set(newValue, forKey: K.coldStartMs) }
    }

    /// 最近一次签到日期（yyyy-MM-dd），小组件用它判断「今天签过没」
    var checkedInDate: String {
        get { defaults.string(forKey: K.checkedInDate) ?? "" }
        set { defaults.set(newValue, forKey: K.checkedInDate) }
    }

    /// 每本小说的阅读进度：chapterId + 滚动偏移
    func readerProgress(_ novelId: Int) -> (chapterId: Int, offset: Int)? {
        guard let raw = defaults.string(forKey: K.readerProgressPrefix + "\(novelId)") else { return nil }
        let parts = raw.split(separator: ":")
        guard parts.count == 2, let cid = Int(parts[0]) else { return nil }
        return (cid, Int(parts[1]) ?? 0)
    }

    func saveReaderProgress(novelId: Int, chapterId: Int, offset: Int) {
        defaults.set("\(chapterId):\(offset)", forKey: K.readerProgressPrefix + "\(novelId)")
    }

    static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
