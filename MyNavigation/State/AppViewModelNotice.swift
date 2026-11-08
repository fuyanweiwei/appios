import Foundation

// ====== 站内通知（AppViewModelNotice.kt 对齐）======

extension AppViewModel {

    /// 拉取未读数（铃铛角标），失败静默
    func refreshNotifUnread() {
        if prefs.userId == 0 { return }
        Task {
            if let json = try? await siteApi().rawGet("api/notification/dynamic/unread", ["userId": "\(prefs.userId)"]) {
                notifUnread = json.optLong("count", 0)
            }
        }
    }

    func loadNotifications() {
        if prefs.userId == 0 { return }
        notifLoading = true
        Task {
            defer { notifLoading = false }
            do {
                let text = try await siteApi().getString(
                    "api/notification/dynamic/list",
                    ["userId": "\(prefs.userId)", "page": "0", "size": "20"]
                )
                let page = Self.parseNotifPage(text)
                notifList = page.arr.objects()
                notifPage = 0
                notifHasMore = page.hasMore
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadNotifications() }, force: true)
            } catch {
                message = "通知加载失败：\(error.localizedDescription)"
            }
        }
    }

    /// A-4 分页返回结构兼容：新后端 {total,page,size,data,hasMore}，旧后端裸数组
    private static func parseNotifPage(_ text: String) -> (arr: [Any], hasMore: Bool) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("[") {
            return (JsonParse.array(t) ?? [], false)
        }
        let json = JsonParse.object(t) ?? [:]
        return (json.optJSONArray("data") ?? [], json.optBoolean("hasMore", false))
    }

    /// 点开一条通知 → 本地即时置已读 + 服务端标记 + 刷新角标
    func markNotifRead(_ id: Int) {
        guard let idx = notifList.firstIndex(where: { $0.optLong("id") == id && !$0.optBoolean("isRead") }) else { return }
        notifList[idx] = notifList[idx].putting("isRead", true)
        if notifUnread > 0 { notifUnread -= 1 }
        Task {
            _ = try? await siteApi().postQuery("api/notification/dynamic/read", ["id": "\(id)"])
        }
    }

    /// 通知加载更多
    func moreNotifications() {
        if !notifHasMore || notifLoading || prefs.userId == 0 { return }
        notifLoading = true
        Task {
            defer { notifLoading = false }
            do {
                let next = notifPage + 1
                let text = try await siteApi().getString(
                    "api/notification/dynamic/list",
                    ["userId": "\(prefs.userId)", "page": "\(next)", "size": "20"]
                )
                let page = Self.parseNotifPage(text)
                let more = page.arr.objects()
                if !more.isEmpty {
                    notifList.append(contentsOf: more)
                    notifPage = next
                }
                notifHasMore = page.hasMore
            } catch { /* 静默：下次滑到底再试 */ }
        }
    }

    /// 全部已 readAll：按 type 过滤，两种类型各调一次
    func markAllNotifRead() {
        notifList = notifList.map { $0.putting("isRead", true) }
        notifUnread = 0
        Task {
            let uid = "\(prefs.userId)"
            for t in ["notification", "dynamic"] {
                _ = try? await siteApi().postQuery("api/notification/dynamic/readAll", ["userId": uid, "type": t])
            }
        }
    }
}
