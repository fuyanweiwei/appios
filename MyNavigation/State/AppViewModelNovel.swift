import Foundation

// ====== P1 小说（AppViewModelNovel.kt 对齐）======

extension AppViewModel {

    func loadNovels() {
        if prefs.baseUrl.isEmpty { return }
        mediaLoading = true
        mediaError = nil
        Task {
            defer { mediaLoading = false }
            do {
                var params: [String: String] = ["page": "0", "pageSize": "\(pageSize)"]
                // 服务端只认 level（0 全年龄 / 1 12+ / 2 18+）
                if let level = mediaFiltersOf(.novels)["level"], !level.isEmpty {
                    params["level"] = level
                }
                let text = try await siteApi().getString("api/novels", params)
                let arr = JsonParse.array(text) ?? []
                novels = Self.parseNovels(arr)
                novelPage = 0
                novelHasMore = arr.count >= pageSize
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadNovels() }, force: false)
            } catch {
                mediaError = error.localizedDescription
                message = "小说列表加载失败：\(error.localizedDescription)"
            }
        }
    }

    /// 小说加载更多
    func moreNovels() {
        if !novelHasMore || loadingMore { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let nextPage = novelPage + 1
                var params: [String: String] = ["page": "\(nextPage)", "pageSize": "\(pageSize)"]
                if let level = mediaFiltersOf(.novels)["level"], !level.isEmpty {
                    params["level"] = level
                }
                let text = try await siteApi().getString("api/novels", params)
                let arr = JsonParse.array(text) ?? []
                let more = Self.parseNovels(arr)
                if !more.isEmpty {
                    novels.append(contentsOf: more)
                    novelPage = nextPage
                }
                novelHasMore = arr.count >= pageSize && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    private static func parseNovels(_ arr: [Any]) -> [NovelBrief] {
        arr.objects().map { o in
            NovelBrief(
                id: o.optLong("id"),
                title: o.optString("title"),
                cover: o.optString("cover"),
                author: o.optString("author"),
                intro: o.optString("intro"),
                words: o.optLong("wordCount", 0),
                reads: o.optInt("readCount", 0)
            )
        }
    }

    func loadNovelDetail(_ novelId: Int) {
        detailLoading = true
        novelDetail = nil
        Task {
            defer { detailLoading = false }
            do {
                let json = try await siteApi().rawGet("api/novels/findNovel/\(novelId)")
                let n = json.optJSONObject("novel") ?? [:]
                let chArr = json.optJSONArray("chapters") ?? []
                let novel = NovelBrief(
                    id: n.optLong("id"),
                    title: n.optString("title"),
                    cover: n.optString("cover"),
                    author: n.optString("author"),
                    intro: n.optString("intro"),
                    words: n.optLong("wordCount", 0),
                    reads: n.optInt("readCount", 0)
                )
                let chapters = chArr.objects().enumerated().map { i, c in
                    NovelChapterRef(
                        id: c.optLong("id"),
                        title: c.optString("chapter"),
                        position: c.optInt("position", i)
                    )
                }.sorted { $0.position < $1.position }
                novelDetail = NovelDetailData(novel: novel, chapters: chapters)
            } catch {
                message = "章节加载失败：\(error.localizedDescription)"
            }
        }
    }

    func loadChapter(_ chapterId: Int) {
        detailLoading = true
        listError = nil
        chapterContent = nil
        Task {
            defer { detailLoading = false }
            do {
                let json = try await siteApi().rawGet("api/novels/findChapter/\(chapterId)")
                chapterContent = json.optString("content")
            } catch {
                listError = error.localizedDescription
                message = "正文加载失败：\(error.localizedDescription)"
            }
        }
    }
}
