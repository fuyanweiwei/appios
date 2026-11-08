import Foundation

// ====== 媒记（梗图 / 壁纸 / 绘画 / 小说）AppViewModelMedia.kt 对齐 ======

extension AppViewModel {

    /// 分区切换：切走再切回不重复拉同一份数据
    func switchMediaSection(_ section: MediaSection) {
        if mediaSection == section { return }
        mediaSection = section
        switch section {
        case .novels:
            if novels.isEmpty { loadNovels() }
        default:
            loadMedia(refresh: true)
        }
    }

    /// 当前分区的过滤条件（空 = 未过滤）
    func mediaFiltersOf(_ section: MediaSection) -> [String: String] {
        mediaFilters[section] ?? [:]
    }

    /// 拉取当前分区列表。refresh=true 从第 0 页重拉，false 加载下一页
    func loadMedia(refresh: Bool) {
        let section = mediaSection
        if section == .novels {
            if refresh { loadNovels() } else { moreNovels() }
            return
        }
        if prefs.baseUrl.isEmpty { return }
        if !refresh && (!mediaHasMore || loadingMore) { return }

        let page = refresh ? 0 : mediaPage + 1
        if refresh {
            mediaLoading = true
            mediaError = nil
        } else {
            loadingMore = true
        }
        Task {
            defer {
                if refresh { mediaLoading = false } else { loadingMore = false }
            }
            do {
                var params: [String: String] = [
                    "page": "\(page)",
                    "pageSize": "\(pageSize)",
                ]
                // 下拉过滤条件（只取当前分区自己的，空值不传）
                for (k, v) in mediaFiltersOf(section) where !v.isEmpty {
                    params[k] = v
                }
                let text = try await siteApi().getString(section.apiPath, params)
                guard let root = JsonParse.object(text) else { throw AuthRequiredException(section.apiPath) }
                let arr = root.optJSONArray("data") ?? []
                let items = arr.objects().compactMap { parseMediaItem($0) }
                mediaItems = refresh ? items : mediaItems + items
                mediaPage = page
                mediaHasMore = items.count >= pageSize
                DiagTrace.step("媒记:\(section.label) 第\(page)页 \(items.count)条(累计\(mediaItems.count))")
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadMedia(refresh: refresh) }, force: false)
            } catch {
                if refresh {
                    mediaError = error.localizedDescription
                } else {
                    message = "加载失败：\(error.localizedDescription)"
                }
            }
        }
    }

    /// 下拉刷新
    func refreshMedia() {
        switch mediaSection {
        case .novels: loadNovels()
        default: loadMedia(refresh: true)
        }
    }

    /// 下拉过滤：只改指定分区的条件，条件变了就回第 0 页重拉
    func setMediaFilters(_ section: MediaSection, _ filters: [String: String]) {
        let cleaned = filters.filter { !$0.value.isEmpty }
        if cleaned.isEmpty {
            mediaFilters.removeValue(forKey: section)
        } else {
            mediaFilters[section] = cleaned
        }
        if mediaSection == section { loadMedia(refresh: true) }
    }

    /// 清空指定分区的过滤（“重置”按钮）
    func clearMediaFilters(_ section: MediaSection) {
        guard mediaFilters[section] != nil else { return }
        mediaFilters.removeValue(forKey: section)
        if mediaSection == section { loadMedia(refresh: true) }
    }

    /// 服务端行 → MediaItem
    private func parseMediaItem(_ o: Json) -> MediaItem? {
        let id = o.optLong("id", 0)
        if id <= 0 { return nil }
        let uploaderId = o.optLong("userId", 0)
        var by = o.optString("drawer")
        if by.isEmpty && uploaderId > 0 { by = userName(uploaderId) }
        return MediaItem(
            id: id,
            name: o.optString("name"),
            url: o.optString("url"),
            by: by,
            tags: o.optString("tags"),
            score: o.optInt("score", 0),
            level: o.optInt("level", 0)
        )
    }
}
