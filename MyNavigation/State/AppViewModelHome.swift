import Foundation

// ====== 首页数据：签到状态 + 日常 + 动态（AppViewModelHome.kt 对齐）======

extension AppViewModel {

    func refreshHome() {
        if prefs.userId == 0 || prefs.baseUrl.isEmpty { return }
        if homeLoading { return }
        homeLoading = true
        listError = nil
        Task {
            do {
                let api = siteApi()
                let status = try await api.rawGet("api/check-in/status", ["userId": "\(prefs.userId)"])
                checkedIn = status.optBoolean("checkedIn", false)
                checkInStreak = status.optInt("streak", 0)
                prefs.streak = checkInStreak

                let daily = try await api.rawGet("api/daily/list", ["page": "0", "size": "20"])
                let arr = daily.optJSONArray("data") ?? []
                homeDailies = arr.objects().compactMap { parseDaily($0) }
                dailyPage = 0
                dailyHasMore = arr.count >= 20
                loadDynamics()
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.refreshHome() }, force: false)
            } catch {
                listError = error.localizedDescription
                message = "首页数据加载失败：\(error.localizedDescription)"
            }
            homeLoading = false
        }
    }

    private func parseDaily(_ o: Json) -> DailyItem? {
        DailyItem(
            id: o.optLong("id"),
            title: o.optString("title"),
            content: o.optString("content"),
            tags: o.optString("tags"),
            createdAt: o.optString("createdAt"),
            authorName: {
                let name = o.optString("authorName")
                return name.isEmpty ? "用户\(o.optLong("userId"))" : name
            }(),
            images: parseImageAttachments(o.optJSONArray("attachments"))
        )
    }

    /// 从日常附件里挑出图片地址（P0-3 配图展示）
    private func parseImageAttachments(_ arr: [Any]?) -> [String] {
        guard let arr else { return [] }
        return arr.objects().compactMap { a in
            let url = a.optString("url")
            if url.isEmpty { return nil }
            let type = a.optString("type")
            let lower = url.lowercased()
            let isImage = type == "image" || lower.contains(".png") || lower.contains(".jpg")
                || lower.contains(".jpeg") || lower.contains(".gif") || lower.contains(".webp")
            return isImage ? url : nil
        }
    }

    /// 日常加载更多 —— A-3 游标分页 + 老后端页码降级 + 按 id 去重
    func moreDailies() {
        if !dailyHasMore || loadingMore || homeLoading { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                var seen = Set(homeDailies.map(\.id))
                let lastId = homeDailies.last?.id ?? 0

                var params: [String: String] = lastId > 0
                    ? ["beforeId": "\(lastId)", "page": "0", "size": "20"]
                    : ["page": "\(dailyPage + 1)", "size": "20"]
                var json = try await siteApi().rawGet("api/daily/list", params)
                var arr = json.optJSONArray("data") ?? []
                var more = arr.objects().compactMap { parseDaily($0) }

                // 降级：服务端忽略 beforeId 时改用页码翻页（否则永久卡死）
                if lastId > 0 && !more.isEmpty && more.allSatisfy({ seen.contains($0.id) }) {
                    params = ["page": "\(dailyPage + 1)", "size": "20"]
                    json = try await siteApi().rawGet("api/daily/list", params)
                    arr = json.optJSONArray("data") ?? []
                    more = arr.objects().compactMap { parseDaily($0) }
                }

                if !more.isEmpty {
                    let fresh = more.filter { seen.insert($0.id).inserted }
                    if !fresh.isEmpty {
                        homeDailies.append(contentsOf: fresh)
                        dailyPage += 1
                    }
                }
                dailyHasMore = arr.count >= 20 && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    /// 动态加载更多（接口一次 50 条，本地分批展示）
    func moreDynamics() {
        if dynamicsShown >= dynamics.count || loadingMore { return }
        dynamicsShown = min(dynamicsShown + 15, dynamics.count)
    }

    /// 动态 = 网站首页「最近更新」
    func loadDynamics() {
        if prefs.baseUrl.isEmpty { return }
        Task {
            guard let text = try? await siteApi().getString("api/activity/recent-aggregated", ["limit": "50"]),
                  let arr = JsonParse.array(text) else { return }
            dynamics = arr.objects().map { o in
                ActivityItem(
                    id: o.optLong("id"),
                    userName: o.optString("_userName"),
                    appType: o.optString("appType"),
                    action: o.optString("action"),
                    summary: o.optString("summary"),
                    createdAt: o.optString("createdAt")
                )
            }
        }
    }

    /// 任务版（首页右上角入口）
    func loadTasks() {
        if prefs.userId == 0 { return }
        Task {
            do {
                let json = try await siteApi().rawGet("api/task-board/today", ["userId": "\(prefs.userId)"])
                tasks = TaskToday(
                    recordCount: json.optInt("recordCount", 0),
                    recordCoins: json.optInt("recordCoins", 0),
                    checkInCoins: json.optInt("checkInCoins", 0),
                    totalCoins: json.optInt("totalCoins", 0),
                    moodDone: json.optBoolean("moodDone", false),
                    coins: json.optInt("coins", 0)
                )
            } catch {
                message = "任务加载失败：\(error.localizedDescription)"
            }
        }
    }
}
