import Foundation

// ====== 贴板（AppViewModelBoard.kt 对齐）======

extension AppViewModel {

    func switchBoardScope(_ scope: String) {
        if boardScope == scope { return }
        boardScope = scope
        loadBoard()
    }

    func loadBoard() {
        if prefs.baseUrl.isEmpty { return }
        boardLoading = true
        listError = nil
        Task {
            do {
                var params: [String: String] = ["scope": boardScope]
                if boardScope == "private" { params["userId"] = "\(prefs.userId)" }
                let json = try await siteApi().rawGet("api/board/list", params)
                boardNotes = (json.optJSONArray("list") ?? []).objects()
                boardShown = 20
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadBoard() }, force: false)
            } catch {
                listError = error.localizedDescription
                message = "贴板加载失败：\(error.localizedDescription)"
            }
            boardLoading = false
        }
    }

    /// 贴板加载更多（本地分批展示）
    func moreBoard() {
        if loadingMore { return }
        if boardShown >= boardNotes.count { return }
        boardShown = min(boardShown + 20, boardNotes.count)
    }

    func saveBoardNote(id: Int?, title: String, content: String, scope: String, alarm: BoardAlarmPayload? = nil) {
        if prefs.userId == 0 { message = "请先登录"; return }
        if title.trimmingCharacters(in: .whitespaces).isEmpty { message = "标题不能为空"; return }
        Task {
            do {
                var body: Json = [
                    "userId": prefs.userId,
                    "title": title.trimmingCharacters(in: .whitespaces),
                    "content": content,
                    "scope": scope,
                ]
                if let id { body["id"] = id }
                // P1-7 邮件闹钟：仅私记、且仅在用户改动过闹钟时才下发
                if let alarm, scope == "private" {
                    body["alarmEnabled"] = alarm.enabled
                    if alarm.enabled {
                        body["alarmAt"] = alarm.atIso
                        body["alarmPeriod"] = alarm.period
                    }
                }
                let json = try await siteApi().postJson("api/board/save", body)
                if json.optBoolean("success") {
                    UsageTracker.record(UsageTracker.BOARD_POST)
                    if alarm?.enabled == true {
                        message = "已保存，闹钟已设置"
                    } else if id == nil {
                        message = "已发布"
                    } else {
                        message = "已保存修改"
                    }
                    popOverlay()
                    loadBoard()
                } else {
                    message = json.optString("message", "保存失败")
                }
            } catch {
                message = "保存失败：\(error.localizedDescription)"
            }
        }
    }
}
