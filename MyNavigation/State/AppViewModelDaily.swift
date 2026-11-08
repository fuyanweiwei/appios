import Foundation

// ====== 发布日常（AppViewModelDaily.kt 对齐）======

extension AppViewModel {

    func composeDaily(title: String, content: String, tags: String, images: [Data] = []) {
        if prefs.userId == 0 { return }
        if title.trimmingCharacters(in: .whitespaces).isEmpty && content.trimmingCharacters(in: .whitespaces).isEmpty {
            message = "写点什么再发布吧"
            return
        }
        uploading = true
        Task {
            defer { uploading = false }
            do {
                let api = siteApi()
                // P0-3：先把配图传到 /api/files/upload，再连同附件提交日常
                var attachments: [Json] = []
                for data in images {
                    let up = try await api.uploadImageJson(path: "api/files/upload?dir=image", data: data)
                    attachments.append([
                        "url": up.optString("url"),
                        "type": up.optString("type", "image"),
                        "originalName": up.optString("originalName"),
                    ])
                }
                var body: Json = [
                    "userId": prefs.userId,
                    "title": title.trimmingCharacters(in: .whitespaces),
                    "content": content.trimmingCharacters(in: .whitespaces),
                    "tags": tags.trimmingCharacters(in: .whitespaces),
                ]
                if !attachments.isEmpty { body["attachments"] = attachments }
                let json = try await api.postJson("api/daily/add", body)
                if json.optBoolean("success") {
                    UsageTracker.record(UsageTracker.DAILY_POST)
                    message = attachments.isEmpty ? "日常已发布" : "日常已发布（含配图）"
                    popOverlay()
                    refreshHome()
                } else {
                    message = json.optString("message", "发布失败")
                }
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.composeDaily(title: title, content: content, tags: tags, images: images) }, force: true)
            } catch {
                message = "发布失败：\(error.localizedDescription)"
            }
        }
    }
}
