import Foundation
import SwiftUI
import Combine

/// 核心 ViewModel（与安卓 AppViewModel.kt 对齐）：
/// 路由、Tab、覆盖层栈、登录/登出、Token 续签、主题、防火墙静默验证、深链。
@MainActor
final class AppViewModel: ObservableObject {

    let prefs = Prefs.shared

    var userId: Int { prefs.userId }
    var baseUrl: String { prefs.baseUrl }
    var apiPassword: String { prefs.apiPassword }
    var username: String { prefs.username }
    var streakCached: Int { prefs.streak }

    func siteApi() -> ApiClient {
        ApiClient(baseUrl: prefs.baseUrl).also {
            $0.userId = prefs.userId
            $0.authToken = prefs.authToken.isEmpty ? nil : prefs.authToken
        }
    }

    @Published var route: Route = Prefs.shared.userId == 0 ? .login : .main

    // ====== 主导航状态（下栏 Tab + 覆盖层栈）======
    @Published var tab: MainTab = .home
    @Published var overlays: [Overlay] = []

    // 小说
    @Published var novels: [NovelBrief] = []
    @Published var novelDetail: NovelDetailData?
    @Published var chapterContent: String?
    @Published var detailLoading = false

    // 功能列表（P2）
    @Published var featureRows: [Json] = []
    @Published var featureLoading = false

    // P3：商城 / 背包 / 成就
    @Published var gifts: [Json] = []
    @Published var backpack: [Json] = []
    @Published var achievements: [Json] = []
    @Published var profileStats: Json?
    @Published var mallLoading = false

    // ====== 站内通知 ======
    @Published var notifUnread = 0
    @Published var notifList: [Json] = []
    @Published var notifLoading = false
    @Published var notifHasMore = false
    var notifPage = 0

    @Published var dynamics: [ActivityItem] = []
    @Published var dynamicsShown = 15

    // 通用分页
    @Published var loadingMore = false
    @Published var dailyPage = 0
    @Published var dailyHasMore = true
    @Published var featurePage = 0
    @Published var featureHasMore = true
    var featureAppType = ""
    @Published var boardShown = 20
    @Published var columnPage = 0
    @Published var columnHasMore = false
    @Published var novelPage = 0
    @Published var novelHasMore = false
    @Published var giftPage = 0
    @Published var giftHasMore = false
    @Published var backpackPage = 0
    @Published var backpackHasMore = false
    @Published var achievementPage = 0
    @Published var achievementHasMore = false
    /// 每页条数（所有列表统一）
    let pageSize = 20

    // 任务版
    @Published var tasks: TaskToday?

    // 贴板
    @Published var boardScope = "public"
    @Published var boardNotes: [Json] = []
    @Published var boardLoading = false

    // 主题
    @Published var themeMode: String = Prefs.shared.themeMode
    @Published var accentIndex: Int = Prefs.shared.accentIndex

    // 首页分栏
    @Published var homeFeed: HomeFeed = .daily

    // 用户表（userId → 昵称）
    @Published var users: [Int: String] = [:]

    // 专栏
    @Published var columns: [Json] = []
    @Published var columnLoading = false

    // 媒记上传中
    @Published var uploading = false

    // ====== 媒记 ======
    @Published var mediaSection: MediaSection = .memes
    @Published var mediaItems: [MediaItem] = []
    @Published var mediaLoading = false
    @Published var mediaError: String?
    @Published var mediaPage = 0
    @Published var mediaHasMore = false
    /// 下拉过滤条件：按分区各存一份（梗图/壁纸/绘画/小说互不干扰）
    @Published var mediaFilters: [MediaSection: [String: String]] = [:]

    // ====== 首页状态：签到 + 日常 ======
    @Published var checkedIn = false
    @Published var checkInStreak = 0
    @Published var homeDailies: [DailyItem] = []
    @Published var homeLoading = false

    @Published var loginBusy = false
    @Published var message: String?
    @Published var authUrl: String?

    var authRetry: (() -> Void)?
    var authDismissed = false
    /// 后台静默验证进行中
    var authTrying = false
    /// 连续自动验证次数（防止死循环）
    var authAutoTries = 0
    var authAutoAt: Date = .distantPast

    // ====== B0-11 断网感知 ======
    @Published var online = true

    // ====== Q-3 加载失败态 ======
    @Published var listError: String?

    // ====== P2-3 排行榜 ======
    @Published var leaderboard: Json?
    @Published var leaderboardLoading = false

    private var cancellables = Set<AnyCancellable>()
    private var initialized = false

    init() {
        // 网络监听：断网显示横幅；恢复在线自动补一次刷新
        Connectivity.observe { [weak self] now in
            Task { @MainActor in
                guard let self else { return }
                let was = self.online
                self.online = now
                if now && !was && self.prefs.userId != 0 {
                    self.refreshHome()
                }
            }
        }
        if prefs.userId != 0 {
            refreshHome()
            loadUsers()
            refreshNotifUnread()
            refreshTokenIfNearExpiry()
        }
    }

    // ====== 登录 / 登出 ======

    func login(username: String, password: String) {
        if username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty {
            message = "请输入用户名和密码"
            return
        }
        if prefs.baseUrl.isEmpty {
            message = "请先在设置中填写站点地址"
            return
        }
        if loginBusy { return }
        loginBusy = true
        Task {
            do {
                let json = try await siteApi().login(username: username.trimmingCharacters(in: .whitespaces), password: password)
                let uid = json.optInt("userId", 0)
                guard uid > 0 else { throw ApiException("登录返回异常") }
                prefs.userId = uid
                prefs.username = username.trimmingCharacters(in: .whitespaces)
                saveTokenFrom(json)
                route = .main
                message = "登录成功"
                refreshHome()
                refreshNotifUnread()
            } catch let e as AuthRequiredException {
                message = "被访问验证页拦截，请先在设置中配置防火墙密码"
                showAuthPage(e.pageUrl, { [weak self] in self?.login(username: username, password: password) }, force: true)
            } catch {
                message = "登录失败：\(error.localizedDescription)"
            }
            loginBusy = false
        }
    }

    // ====== P1-3 阅读器偏好 ======

    func getReaderFontScale() -> Double { prefs.readerFontScale }
    func setReaderFontScale(_ v: Double) { prefs.readerFontScale = v }
    func getReaderNight() -> Bool { prefs.readerNight }
    func setReaderNight(_ v: Bool) { prefs.readerNight = v }
    func getReaderProgress(_ novelId: Int) -> (chapterId: Int, offset: Int)? { prefs.readerProgress(novelId) }
    func saveReaderProgress(novelId: Int, chapterId: Int, offset: Int) {
        prefs.saveReaderProgress(novelId: novelId, chapterId: chapterId, offset: offset)
    }

    // ====== A-2 Token ======

    func saveTokenFrom(_ json: Json) {
        let token = json.optString("token")
        if !token.isEmpty {
            prefs.authToken = token
            prefs.tokenExpiresAt = json.optLong("expiresAt", 0)
        }
    }

    /// Token 到期前 3 天静默续签
    func refreshTokenIfNearExpiry(force: Bool = false) {
        if prefs.userId == 0 || prefs.authToken.isEmpty { return }
        let expiresAt = prefs.tokenExpiresAt
        let now = Int(Date().timeIntervalSince1970 * 1000)
        if !force && expiresAt > 0 && now < expiresAt - 3 * 86_400_000 { return }
        Task {
            let json = await siteApi().refreshToken()
            if json.optBoolean("success") {
                saveTokenFrom(json)
            } else if json.optString("message").contains("失效") {
                prefs.authToken = ""
                prefs.tokenExpiresAt = 0
            }
        }
    }

    func logout() {
        Task {
            try? await siteApi().logout()
            prefs.userId = 0
            prefs.username = ""
            prefs.authToken = ""
            prefs.tokenExpiresAt = 0
            homeDailies = []
            checkedIn = false
            checkInStreak = 0
            overlays = []
            tab = .home
            route = .login
            message = "已退出登录"
        }
    }

    // ====== 主题 ======

    func setThemeMode(_ mode: String) {
        prefs.themeMode = mode
        themeMode = mode
    }

    func setAccentIndex(_ index: Int) {
        prefs.accentIndex = index
        accentIndex = index
    }

    func setHomeFeed(_ feed: HomeFeed) {
        homeFeed = feed
        switch feed {
        case .daily: refreshHome()
        case .column: loadColumns()
        case .dynamic: if dynamics.isEmpty { loadDynamics() }
        }
    }

    /// 把任意 userId 渲染成用户名
    func userName(_ id: Int) -> String {
        if let name = users[id] { return name }
        if id == prefs.userId && !prefs.username.isEmpty { return prefs.username }
        return "用户\(id)"
    }

    func loadUsers() {
        if prefs.baseUrl.isEmpty { return }
        Task {
            guard let text = try? await siteApi().getString("api/user/all"),
                  let arr = JsonParse.array(text) else { return }
            var map: [Int: String] = [:]
            for o in arr.objects() {
                let id = o.optLong("id", -1)
                if id <= 0 { continue }
                var name = o.optString("nickname")
                if name.isEmpty { name = o.optString("username") }
                if !name.isEmpty { map[id] = name }
            }
            users = map
        }
    }

    func doCheckIn() {
        if prefs.userId == 0 { return }
        Task {
            do {
                let json = try await siteApi().postQuery("api/check-in/do", ["userId": "\(prefs.userId)"])
                let reward = json.optInt("coinsReward", 0)
                let streak = json.optInt("streak", 0)
                checkedIn = true
                checkInStreak = streak
                prefs.streak = streak
                // P4-1：记下今天已签，桌面小组件据此显示「已签到 ✓」
                prefs.checkedInDate = Prefs.today()
                UsageTracker.record(UsageTracker.CHECK_IN)
                message = "签到成功：连续 \(streak) 天，+\(reward) 金币"
                loadProfileStats()
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.doCheckIn() }, force: true)
            } catch {
                message = error.localizedDescription
            }
        }
    }

    // ====== P4：分享接收 → 贴板 ======

    func shareToBoard(_ text: String) {
        if prefs.userId == 0 {
            message = "登录后才能保存分享内容"
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        Task {
            do {
                let title = String(trimmed.prefix(40)).replacingOccurrences(of: "\n", with: " ")
                let body: Json = [
                    "userId": prefs.userId,
                    "title": title,
                    "content": trimmed,
                    "scope": "private",
                ]
                let json = try await siteApi().postJson("api/board/save", body)
                if json.optBoolean("success") {
                    message = "已保存到贴板"
                } else {
                    message = json.optString("message", "保存失败")
                }
            } catch {
                message = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    func clearMessage() { message = nil }
    func showMessage(_ text: String) { message = text }

    func saveApiSettings(url: String, password: String) {
        prefs.baseUrl = url
        prefs.apiPassword = password
        ImageBase.baseUrl = url
        authDismissed = false
        message = "已保存 API 设置"
        refreshHome()
    }

    func closeAuthPage() {
        authDismissed = true
        authUrl = nil
        authRetry = nil
    }

    func retryAfterAuth() {
        let retry = authRetry
        authDismissed = false
        authRetry = nil
        authAutoTries = 0
        authTrying = false
        authUrl = nil
        retry?()
    }

    func openSettings() { pushOverlay(.settings) }
    func backFromSettings() { popOverlay() }

    // ====== 覆盖层导航 ======

    func pushOverlay(_ o: Overlay) {
        if overlays.last == o { return }
        overlays.append(o)
        // 进入时按需加载 + 记使用统计（Q-11）
        switch o {
        case .gift: loadGifts()
        case .backpack: loadBackpack()
        case .achievement: loadAchievements()
        case let .featureList(appType, _): loadFeatureList(appType)
        case let .novelDetail(novelId, _): loadNovelDetail(novelId)
        case let .novelReader(_, chapterId, _):
            loadChapter(chapterId)
            UsageTracker.record(UsageTracker.NOVEL_READ)
        case .mediaViewer:
            UsageTracker.record(UsageTracker.MEDIA_VIEW)
        case .gameContainer:
            UsageTracker.record(UsageTracker.GAME_OPEN)
        default: break
        }
    }

    func popOverlay() {
        guard !overlays.isEmpty else { return }
        overlays.removeLast()
    }

    func selectTab(_ tab: MainTab) {
        DiagTrace.step("selectTab → \(tab.rawValue)")
        self.tab = tab
        switch tab {
        case .home:
            refreshHome(); loadUsers(); refreshNotifUnread()
        case .board:
            loadBoard()
        case .media:
            break // 媒记由 MediaTab 按需加载
        case .features:
            break // 点 Tab 不弹消息
        case .tools:
            break // 实用页全部本地计算
        }
    }

    /// P4-4 深链路由：`mynavigation://<目标>`
    func navigateDeepLink(_ target: String) {
        guard route == .main else { return }
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        let clean = trimmed.contains("://") ? String(trimmed.split(separator: "/").dropFirst().joined(separator: "/").split(separator: "?").first ?? "") : trimmed
        // 兼容两种入参：完整 mynavigation://board 或 host（board）
        let afterScheme: String
        if let range = trimmed.range(of: "://") {
            afterScheme = String(trimmed[range.upperBound...])
        } else {
            afterScheme = trimmed
        }
        let key = afterScheme.lowercased().split(separator: "/").first.map(String.init)?
            .split(separator: "?").first.map(String.init) ?? ""
        _ = clean
        switch key {
        case "", "home", "index":
            selectTab(.home)
        case "board":
            selectTab(.board)
        case "media", "meme", "wallpaper", "photo", "draw", "novel":
            selectTab(.media)
            let subParts = afterScheme.lowercased().split(separator: "/")
            let sub = subParts.count > 1 ? String(subParts[1]).split(separator: "?").first.map(String.init) ?? "" : ""
            let effective = sub.isEmpty ? key : sub
            let sec: MediaSection?
            switch effective {
            case "meme": sec = .memes
            case "wallpaper", "photo": sec = .photos
            case "draw": sec = .draws
            case "novel": sec = .novels
            default: sec = nil
            }
            if let sec { switchMediaSection(sec) }
        case "features", "feature":
            selectTab(.features)
        case "tools", "tool":
            selectTab(.tools)
        case "profile", "mine", "user":
            pushOverlay(.profile)
        case "notifications", "notice":
            pushOverlay(.notifications)
        case "feedback":
            pushOverlay(.feedback)
        case "settings":
            pushOverlay(.settings)
        case "tasks", "task":
            pushOverlay(.tasks)
        case "daily":
            selectTab(.home)
            pushOverlay(.composeDaily)
        default:
            message = "不认识的链接：\(key)，已回到首页"
            selectTab(.home)
        }
    }

    // ====== 防火墙静默验证 ======

    func showAuthPage(_ url: String, _ retry: @escaping () -> Void, force: Bool) {
        authRetry = retry
        if authUrl != nil { return }
        if authDismissed && !force { return }
        silentAuth(url)
    }

    /// 后台自动提交防火墙密码；用户体感就是“直接进了主页”
    func silentAuth(_ url: String) {
        let password = prefs.apiPassword
        if authTrying { return }
        if password.isEmpty {
            authUrl = url
            return
        }
        let now = Date()
        if now.timeIntervalSince(authAutoAt) > 30 { authAutoTries = 0 }
        if authAutoTries >= 3 {
            authUrl = url
            return
        }
        authTrying = true
        authAutoAt = now
        authAutoTries += 1
        Task {
            let ok = (try? await siteApi().authenticate(pageUrl: url, password: password)) ?? false
            authTrying = false
            if ok {
                authDismissed = false
                let pending = authRetry
                authRetry = nil
                pending?()
                refreshHome()
            } else {
                authUrl = url
            }
        }
    }
}

/// Kotlin 扩展风格的小助手
private extension ApiClient {
    func also(_ block: (ApiClient) -> Void) -> ApiClient {
        block(self)
        return self
    }
}
