import Foundation

// ====== P3：商城 / 背包 / 成就 / 个人统计（AppViewModelMall.kt 对齐）======

extension AppViewModel {

    func loadGifts() {
        mallLoading = true
        Task {
            do {
                // admin/list：包含全部商品（含未上架）与上传人 userId
                let text = try await siteApi().getString("api/gift/admin/list", ["page": "0", "pageSize": "\(pageSize)"])
                let arr = JsonParse.array(text) ?? []
                gifts = arr.objects()
                giftPage = 0
                giftHasMore = arr.count >= pageSize
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadGifts() }, force: false)
            } catch {
                message = "商城加载失败：\(error.localizedDescription)"
            }
            mallLoading = false
        }
    }

    func moreGifts() {
        if !giftHasMore || loadingMore || mallLoading { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let nextPage = giftPage + 1
                let text = try await siteApi().getString("api/gift/admin/list", ["page": "\(nextPage)", "pageSize": "\(pageSize)"])
                let arr = JsonParse.array(text) ?? []
                let more = arr.objects()
                if !more.isEmpty {
                    gifts.append(contentsOf: more)
                    giftPage = nextPage
                }
                giftHasMore = arr.count >= pageSize && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    /// 上架 / 编辑自己的商品（带 userId 归属校验）
    func saveGift(id: Int?, name: String, icon: String, type: String,
                  cost: Int, stock: Int, message: String, active: Bool) {
        if prefs.userId == 0 { self.message = "请先登录"; return }
        if name.trimmingCharacters(in: .whitespaces).isEmpty { self.message = "名称不能为空"; return }
        Task {
            do {
                let body: Json = [
                    "name": name.trimmingCharacters(in: .whitespaces),
                    "icon": icon.isEmpty ? "fa-gift" : icon,
                    "type": type,
                    "coinsCost": cost,
                    "stock": stock,
                    "message": message,
                    "isActive": active,
                    "userId": prefs.userId,
                ]
                let path = id == nil ? "api/gift/admin/add" : "api/gift/admin/\(id!)"
                let text = id == nil
                    ? try await siteApi().postText(path, JsonParse.encode(body))
                    : try await siteApi().putText(path, JsonParse.encode(body))
                let json = JsonParse.object(text.trimmingCharacters(in: .whitespaces).hasPrefix("{") ? text : "{\"success\":true}") ?? ["success": true]
                if json.optBoolean("success", true) {
                    self.message = id == nil ? "已上架" : "已保存"
                    popOverlay()
                    loadGifts()
                } else {
                    self.message = json.optString("message", "保存失败")
                }
            } catch {
                self.message = "保存失败：\(error.localizedDescription)"
            }
        }
    }

    func deleteGift(id: Int) {
        Task {
            do {
                let ok = try await siteApi().delete("api/gift/admin/\(id)", ["userId": "\(prefs.userId)"])
                message = ok ? "已删除" : "删除失败（只能删自己的）"
                loadGifts()
            } catch {
                message = "删除失败：\(error.localizedDescription)"
            }
        }
    }

    func exchangeGift(giftId: Int) {
        if prefs.userId == 0 { return }
        Task {
            do {
                let json = try await siteApi().postQuery("api/gift/exchange", ["userId": "\(prefs.userId)", "giftId": "\(giftId)"])
                let msg = json.optString("message")
                message = msg.isEmpty ? (json.optBoolean("success") ? "兑换成功" : "兑换失败") : msg
                if json.optBoolean("success") {
                    loadGifts()
                    loadProfileStats()
                }
            } catch {
                message = error.localizedDescription
            }
        }
    }

    func loadBackpack() {
        mallLoading = true
        Task {
            do {
                let text = try await siteApi().getString("api/gift/backpack", [
                    "userId": "\(prefs.userId)", "page": "0", "pageSize": "\(pageSize)",
                ])
                let arr = JsonParse.array(text) ?? []
                backpack = arr.objects()
                backpackPage = 0
                backpackHasMore = arr.count >= pageSize
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadBackpack() }, force: false)
            } catch {
                message = "背包加载失败：\(error.localizedDescription)"
            }
            mallLoading = false
        }
    }

    func moreBackpack() {
        if !backpackHasMore || loadingMore || mallLoading { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let nextPage = backpackPage + 1
                let text = try await siteApi().getString("api/gift/backpack", [
                    "userId": "\(prefs.userId)", "page": "\(nextPage)", "pageSize": "\(pageSize)",
                ])
                let arr = JsonParse.array(text) ?? []
                let more = arr.objects()
                if !more.isEmpty {
                    backpack.append(contentsOf: more)
                    backpackPage = nextPage
                }
                backpackHasMore = arr.count >= pageSize && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    func loadAchievements() {
        mallLoading = true
        Task {
            do {
                let json = try await siteApi().rawGet("api/achievement/unlocked", [
                    "userId": "\(prefs.userId)", "page": "0", "pageSize": "\(pageSize)",
                ])
                let arr = json.optJSONArray("unlocked") ?? []
                achievements = arr.objects()
                achievementPage = 0
                achievementHasMore = arr.count >= pageSize
            } catch let e as AuthRequiredException {
                showAuthPage(e.pageUrl, { [weak self] in self?.loadAchievements() }, force: false)
            } catch {
                message = "成就加载失败：\(error.localizedDescription)"
            }
            mallLoading = false
        }
    }

    func moreAchievements() {
        if !achievementHasMore || loadingMore || mallLoading { return }
        loadingMore = true
        Task {
            defer { loadingMore = false }
            do {
                let nextPage = achievementPage + 1
                let json = try await siteApi().rawGet("api/achievement/unlocked", [
                    "userId": "\(prefs.userId)", "page": "\(nextPage)", "pageSize": "\(pageSize)",
                ])
                let arr = json.optJSONArray("unlocked") ?? []
                let more = arr.objects()
                if !more.isEmpty {
                    achievements.append(contentsOf: more)
                    achievementPage = nextPage
                }
                achievementHasMore = arr.count >= pageSize && !more.isEmpty
            } catch { /* 静默 */ }
        }
    }

    func loadProfileStats() {
        if prefs.userId == 0 { return }
        Task {
            profileStats = try? await siteApi().rawGet("api/achievement/stats", ["userId": "\(prefs.userId)"])
        }
    }
}
