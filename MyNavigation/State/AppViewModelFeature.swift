import Foundation

// ====== P2 功能列表（AppViewModelFeature.kt 对齐）======

extension AppViewModel {

    func loadFeatureList(_ appType: String) {
        featureLoading = true
        listError = nil
        featureRows = []
        featureAppType = appType
        featurePage = 0
        featureHasMore = appType != "my_best"
        Task {
            do {
                let rows: [Json]
                if appType == "my_best" {
                    let text = try await siteApi().getString("api/app/myBest/findAll")
                    rows = (JsonParse.array(text) ?? []).objects()
                } else {
                    let json = try await siteApi().rawGet("api/feature-data/\(appType)/list", ["page": "0", "size": "20"])
                    let arr = json.optJSONArray("data") ?? []
                    featureHasMore = arr.count >= 20
                    rows = arr.objects()
                }
                featureRows = rows
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadFeatureList(appType) }, force: false)
            } catch {
                listError = error.localizedDescription
                message = "加载失败：\(error.localizedDescription)"
            }
            featureLoading = false
        }
    }

    /// 功能列表加载更多
    func moreFeatureList() {
        if !featureHasMore || loadingMore || featureLoading { return }
        if featureAppType.isEmpty || featureAppType == "my_best" { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let nextPage = featurePage + 1
                let json = try await siteApi().rawGet("api/feature-data/\(featureAppType)/list", ["page": "\(nextPage)", "size": "20"])
                let arr = json.optJSONArray("data") ?? []
                let more = arr.objects()
                if !more.isEmpty {
                    featureRows.append(contentsOf: more)
                    featurePage = nextPage
                }
                featureHasMore = arr.count >= 20 && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    /// 通用保存：新增 POST，编辑 PUT。字段全按字符串发；
    /// 只有 PUT 走反射需要精确字段名，所以暗区的 `kill` 编辑时改名 `kills`。
    func saveFeature(appType: String, id: Int?, values: [String: String]) {
        if prefs.userId == 0 {
            message = "请先登录"
            return
        }
        let filled = values.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        if filled.isEmpty {
            message = "至少填一项再保存"
            return
        }
        Task {
            do {
                let api = siteApi()
                var body: Json = ["userId": prefs.userId]
                for (k, v) in filled {
                    let key = (id != nil && appType == "anwei_game" && k == "kill") ? "kills" : k
                    body[key] = v
                }
                let json: Json
                if id == nil {
                    json = try await api.postJson("api/feature-data/\(appType)/add", body)
                } else {
                    let text = try await api.putText("api/feature-data/\(appType)/\(id!)", JsonParse.encode(body))
                    json = JsonParse.object(text) ?? [:]
                }
                if json.optBoolean("success") {
                    if id == nil { UsageTracker.record(UsageTracker.FEATURE_ADD) }
                    message = id == nil ? "已添加一条记录" : "已保存修改"
                    popOverlay()
                    // 详情页数据已过期，一并关掉回列表
                    if overlays.last.map({ if case .featureDetail = $0 { return true } else { return false } }) == true {
                        popOverlay()
                    }
                    loadFeatureList(appType)
                } else {
                    message = json.optString("message", "保存失败")
                }
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.saveFeature(appType: appType, id: id, values: values) }, force: true)
            } catch {
                message = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    /// 删除单条记录（仅本人记录）
    func deleteFeature(appType: String, id: Int) {
        if prefs.userId == 0 {
            message = "请先登录"
            return
        }
        Task {
            do {
                let ok = try await siteApi().delete("api/feature-data/\(appType)/\(id)")
                message = ok ? "已删除" : "删除失败"
                popOverlay()
                loadFeatureList(appType)
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.deleteFeature(appType: appType, id: id) }, force: true)
            } catch {
                message = "删除失败：\(error.localizedDescription)"
            }
        }
    }

    func loadLeaderboard() {
        if prefs.baseUrl.isEmpty { return }
        leaderboardLoading = true
        Task {
            do {
                leaderboard = try await siteApi().rawGet("api/leaderboard/month")
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadLeaderboard() }, force: false)
            } catch {
                message = "排行榜加载失败：\(error.localizedDescription)"
            }
            leaderboardLoading = false
        }
    }

    /// Q-2：功能 Tab 的下拉刷新——有打开过的列表就重载，没有就静默返回
    func refreshFeatures() {
        let current = featureAppType
        if current.isEmpty { return }
        loadFeatureList(current)
    }
}
