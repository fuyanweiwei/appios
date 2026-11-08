import Foundation

// ====== 专栏（AppViewModelColumn.kt 对齐）======

extension AppViewModel {

    func loadColumns() {
        if prefs.baseUrl.isEmpty { return }
        columnLoading = true
        Task {
            do {
                let json = try await siteApi().rawGet("api/column/list", ["page": "0", "size": "\(pageSize)"])
                let arr = json.optJSONArray("data") ?? []
                columns = arr.objects()
                columnPage = 0
                columnHasMore = arr.count >= pageSize
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadColumns() }, force: false)
            } catch {
                message = "专栏加载失败：\(error.localizedDescription)"
            }
            columnLoading = false
        }
    }

    /// 专栏加载更多
    func moreColumns() {
        if !columnHasMore || loadingMore || columnLoading { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let nextPage = columnPage + 1
                let json = try await siteApi().rawGet("api/column/list", ["page": "\(nextPage)", "size": "\(pageSize)"])
                let arr = json.optJSONArray("data") ?? []
                let more = arr.objects()
                if !more.isEmpty {
                    columns.append(contentsOf: more)
                    columnPage = nextPage
                }
                columnHasMore = arr.count >= pageSize && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    func saveColumn(id: Int?, title: String, content: String, type: String) {
        if prefs.userId == 0 { message = "请先登录"; return }
        if title.trimmingCharacters(in: .whitespaces).isEmpty { message = "标题不能为空"; return }
        Task {
            do {
                let body: Json = [
                    "userId": prefs.userId,
                    "title": title.trimmingCharacters(in: .whitespaces),
                    "content": content,
                    "type": type,
                ]
                let path = id == nil ? "api/column/add" : "api/column/\(id!)"
                let json: Json
                if id == nil {
                    json = try await siteApi().postJson(path, body)
                } else {
                    // 编辑必须走 PUT（POST 会 405/500）
                    let text = try await siteApi().putText(path, JsonParse.encode(body))
                    json = JsonParse.object(text.contains("{") ? text : "{\"success\":true}") ?? ["success": true]
                }
                if json.optBoolean("success", true) {
                    message = id == nil ? "专栏已发布" : "专栏已保存"
                    popOverlay()
                    loadColumns()
                } else {
                    message = json.optString("message", "保存失败")
                }
            } catch {
                message = "保存失败：\(error.localizedDescription)"
            }
        }
    }
}
