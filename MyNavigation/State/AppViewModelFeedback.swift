import Foundation

// ====== P0-6 反馈 / 评分（AppViewModelFeedback.kt 对齐）======

extension AppViewModel {

    /// 提交需求反馈（/api/requirement/save）
    func submitFeedback(type: String, level: String, content: String) {
        if prefs.userId == 0 {
            message = "请先登录后再提交反馈"
            return
        }
        if type.isEmpty {
            message = "请选择需求类型"
            return
        }
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            message = "请描述你的需求"
            return
        }
        Task {
            do {
                let body: Json = [
                    "type": type,
                    "level": level.isEmpty ? "中" : level,
                    "content": content.trimmingCharacters(in: .whitespaces),
                    "userId": prefs.userId,
                    "submitter": prefs.username,
                ]
                let json = try await siteApi().postJson("api/requirement/save", body)
                if json.optBoolean("success") {
                    message = "反馈已提交，感谢！"
                    popOverlay()
                } else {
                    message = json.optString("message", "提交失败")
                }
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.submitFeedback(type: type, level: level, content: content) }, force: true)
            } catch {
                message = "提交失败：\(error.localizedDescription)"
            }
        }
    }

    /// 应用内星级评分（/api/function-rating/save）
    func submitAppRating(score: Int, reason: String) {
        if prefs.userId == 0 {
            message = "请先登录后再评分"
            return
        }
        Task {
            do {
                var body: Json = [
                    "userId": prefs.userId,
                    "module": "iOS App",
                    "item": "整体体验",
                    "score": score,
                ]
                if !reason.trimmingCharacters(in: .whitespaces).isEmpty {
                    body["reason"] = reason.trimmingCharacters(in: .whitespaces)
                }
                let json = try await siteApi().postJson("api/function-rating/save", body)
                if json.optBoolean("success") {
                    message = "评分已提交，感谢！"
                } else {
                    message = json.optString("message", "评分失败")
                }
            } catch {
                message = "评分失败：\(error.localizedDescription)"
            }
        }
    }
}
