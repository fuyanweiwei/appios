import SwiftUI

// ====== P3：商城 / 背包 / 成就（MallScreens.kt 对齐）======

/* ============ 商城（按上传人分类 / 编辑自己的 / 上架） ============ */

struct GiftScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    /// nil = 全部上传人，-1 = 仅看我的
    @State private var uploaderFilter: Int? = nil
    @State private var showExchange = false
    @State private var pendingExchange: Json?
    @State private var showDelete = false
    @State private var pendingDelete: Json?

    private var filtered: [Json] {
        guard let filter = uploaderFilter else { return vm.gifts }
        if filter == -1 {
            return vm.gifts.filter { $0.optLong("userId", -1) == vm.userId }
        }
        return vm.gifts.filter { $0.optLong("userId", -1) == filter }
    }

    var body: some View {
        OverlayScaffold(title: "商城") {
            VStack(spacing: 0) {
                filterBar
                stateContent
            }
        }
        // FAB 上架
        .overlay(alignment: .bottomTrailing) { fab }
        .onAppear { vm.loadUsers() }
        .alert("兑换确认", isPresented: $showExchange, presenting: pendingExchange) { gift in
            Button("兑换") { vm.exchangeGift(giftId: gift.optLong("id")) }
            Button("取消", role: .cancel) {}
        } message: { gift in
            Text("确定用 \(gift.optInt("coinsCost", 0)) 金币兑换「\(gift.optString("name", "商品"))」吗？")
        }
        .alert("删除商品？", isPresented: $showDelete, presenting: pendingDelete) { gift in
            Button("删除", role: .destructive) { vm.deleteGift(id: gift.optLong("id")) }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("删除后无法恢复")
        }
    }

    // ---- 上传人筛选 ----

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker(uploaderLabel, selection: $uploaderFilter) {
                Text("全部上传人").tag(Optional<Int>.none)
                Text("我上架的").tag(Optional(-1))
                ForEach(vm.users.keys.sorted(), id: \.self) { id in
                    Text(vm.users[id] ?? "用户\(id)").tag(Optional(id))
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 12))
            .tint(palette.onSurfaceVariant)
            .frame(maxWidth: 200, minHeight: 44)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(palette.outline)
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var uploaderLabel: String {
        guard let filter = uploaderFilter else { return "全部上传人" }
        if filter == -1 { return "我上架的" }
        return vm.users[filter] ?? "用户\(filter)"
    }

    // ---- 三态 ----

    @ViewBuilder
    private var stateContent: some View {
        if vm.mallLoading && vm.gifts.isEmpty {
            ProgressView()
                .controlSize(.large)
                .tint(palette.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        } else if filtered.isEmpty {
            Text("暂无商品")
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 120)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(filtered.indices, id: \.self) { i in
                    let gift = filtered[i]
                    GiftCard(
                        gift: gift,
                        uploader: uploaderName(gift),
                        mine: gift.optLong("userId", -1) == vm.userId,
                        onExchange: {
                            pendingExchange = gift
                            showExchange = true
                        },
                        onEdit: { vm.pushOverlay(.giftEdit(gift: gift)) },
                        onDelete: {
                            pendingDelete = gift
                            showDelete = true
                        }
                    )
                }
                if vm.giftHasMore {
                    Text("上滑加载更多…")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                LoadMoreEffect(hasMore: vm.giftHasMore, loading: vm.loadingMore) {
                    vm.moreGifts()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    private func uploaderName(_ gift: Json) -> String {
        let uid = gift.optLong("userId", -1)
        if let name = vm.users[uid] { return name }
        return uid > 0 ? "用户\(uid)" : "官方"
    }

    // ---- 上架 FAB ----

    private var fab: some View {
        Button {
            vm.pushOverlay(.giftEdit(gift: nil))
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(palette.onPrimary)
                .frame(width: 54, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 17)
                        .fill(palette.primary)
                        .shadow(color: palette.primary.opacity(0.35), radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
        .padding(18)
    }
}

private struct GiftCard: View {
    let gift: Json
    let uploader: String
    let mine: Bool
    let onExchange: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.palette) var palette

    private var active: Bool { gift.optBoolean("isActive", true) }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(giftIcon)
                .font(.system(size: 26))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(gift.optString("name", "商品"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                    if !active {
                        Text("未上架")
                            .font(.system(size: 10))
                            .foregroundStyle(palette.onErrorContainer)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(palette.errorContainer)
                            )
                    }
                }

                let message = gift.optString("message")
                if !message.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .lineLimit(2)
                }

                Text("\(gift.optInt("coinsCost", 0)) 金币 · 库存 \(gift.optInt("stock", 0)) · 上传：\(uploader)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if mine {
                VStack(spacing: 4) {
                    Button(action: onEdit) {
                        Text("编辑")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.primary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDelete) {
                        Text("删除")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onErrorContainer)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            if active {
                Button(action: onExchange) {
                    Text("兑换")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(palette.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        )
    }

    /// 图标：emoji 直接用；网页旧值 fa-gift 归一成 🎁
    private var giftIcon: String {
        let icon = gift.optString("icon", "🎁")
        if icon.isEmpty || icon == "fa-gift" { return "🎁" }
        return String(icon.prefix(2))
    }
}

/* ============ P3 背包 ============ */

struct BackpackScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        OverlayScaffold(title: "我的背包") {
            if vm.mallLoading && vm.backpack.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .tint(palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if vm.backpack.isEmpty {
                Text("背包空空如也，去商城逛逛")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 120)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.backpack.indices, id: \.self) { i in
                        let item = vm.backpack[i]
                        backpackRow(item)
                    }
                    if vm.backpackHasMore {
                        Text("上滑加载更多…")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    LoadMoreEffect(hasMore: vm.backpackHasMore, loading: vm.loadingMore) {
                        vm.moreBackpack()
                    }
                }
                .padding(14)
            }
        }
    }

    private func backpackRow(_ item: Json) -> some View {
        HStack(spacing: 12) {
            Text("🧧")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.optString("name", "物品") + " ×" + String(item.optInt("qty", 1)))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.onBackground)
                if item.optBoolean("isUsed", false) {
                    Text("已使用")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                } else if !item.optString("message").trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(item.optString("message"))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        )
    }
}

/* ============ P3 成就（ACH_DEFS 全量 55 项） ============ */

struct AchievementScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    /// achievementId → 解锁记录
    private var unlockedById: [String: Json] {
        var map: [String: Json] = [:]
        for a in vm.achievements {
            let key = a.optString("achievementId")
            if !key.isEmpty { map[key] = a }
        }
        return map
    }

    var body: some View {
        OverlayScaffold(title: "成就") {
            if vm.mallLoading && vm.achievements.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .tint(palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                let unlocked = unlockedById
                LazyVStack(spacing: 10) {
                    if unlocked.isEmpty {
                        VStack(spacing: 8) {
                            Text("🏆")
                                .font(.system(size: 40))
                            Text("还没有解锁成就，多来玩玩")
                                .font(.system(size: 14))
                                .foregroundStyle(palette.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }

                    ForEach(ACH_DEFS) { def in
                        achievementRow(def, unlocked: unlocked[def.id])
                    }

                    if vm.achievementHasMore {
                        Text("上滑加载更多…")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    LoadMoreEffect(hasMore: vm.achievementHasMore, loading: vm.loadingMore) {
                        vm.moreAchievements()
                    }
                }
                .padding(14)
            }
        }
    }

    private func achievementRow(_ def: AchDef, unlocked: Json?) -> some View {
        HStack(spacing: 12) {
            Text(def.icon)
                .font(.system(size: 24))
                .opacity(unlocked == nil ? 0.4 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(def.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(unlocked == nil ? palette.onSurfaceVariant : palette.onBackground)
                if let unlocked {
                    Text(def.desc + " · 解锁于 " + String(unlocked.optString("unlockedAt").prefix(10)))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                } else {
                    Text(def.desc)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if unlocked != nil {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(unlocked == nil ? palette.surfaceVariant.opacity(0.5) : palette.surface)
                .shadow(color: .black.opacity(unlocked == nil ? 0 : 0.06), radius: 1, y: 1)
        )
        .opacity(unlocked == nil ? 0.7 : 1)
    }
}
