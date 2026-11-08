import SwiftUI
import UIKit

// ====== 功能 Tab（FeaturesTab.kt 对齐）：九宫格入口 + 通用功能列表 / 详情 / 我的最佳卡 ======

/// 网站各功能页同款筛选控件类型（TEXT 文本 / SELECT 下拉 / NUMBER_MIN 下限 / RANGE 区间）
enum FKind { case TEXT, SELECT, NUMBER_MIN, RANGE }

/// 单个筛选控件（安卓 FSpec）
struct FSpec: Identifiable {
    let key: String
    let label: String
    let kind: FKind
    let options: [String]
    var id: String { key }

    init(_ key: String, _ label: String, _ kind: FKind, _ options: [String] = []) {
        self.key = key
        self.label = label
        self.kind = kind
        self.options = options
    }
}

/// 各功能的过滤器定义（与安卓 FEATURE_FILTERS 逐条一致；过滤在本地对 vm.featureRows 做）
let FEATURE_FILTERS: [String: [FSpec]] = [
    "comic_watch": [
        FSpec("year", "年份", .SELECT, (2010...2030).map { String($0) }),
    ],
    "anwei_game": [
        FSpec("gameType", "游戏", .SELECT, ["暗围", "摸金"]),
    ],
    "character_memory": [
        FSpec("animeType", "动漫类型", .TEXT),
        FSpec("characterType", "角色类型", .SELECT, ["主角", "配角", "反派", "路人"]),
        FSpec("gender", "性别", .SELECT, ["男", "女", "其他"]),
    ],
    "anime_music_echo": [
        FSpec("animeType", "动漫类型", .TEXT),
        FSpec("musicType", "音乐类型", .SELECT, ["OP", "ED", "插曲", "角色歌", "其他"]),
    ],
    "deep_rock_galaxy": [
        FSpec("missionType", "任务类型", .SELECT, ["采矿探险", "虫蛋收集", "就地精炼", "搜救行动", "定点提取", "消灭任务", "执勤护送", "设施破坏", "重型探采", "深层扫描"]),
        FSpec("mapName", "地图", .SELECT, ["水晶洞穴", "盐坑", "霉菌沼泽", "放射性禁区", "密林丛原", "冰封岩层", "熔岩之心", "飞沙走廊", "蔚蓝花甸", "藤络树洞", "栖骨深渊"]),
        FSpec("character", "角色", .SELECT, ["侦察兵", "钻机手", "枪手", "工程师"]),
    ],
    "elden_ring": [
        FSpec("character", "角色", .SELECT, ["追踪者", "铁之眼", "隐士", "无赖"]),
        FSpec("destination", "终点", .TEXT),
        FSpec("isWin", "通关", .SELECT, ["否", "是"]),
    ],
    "food_record": [
        FSpec("type", "类型", .TEXT),
        FSpec("scores", "评分", .TEXT),
    ],
    "mc_mod": [
        FSpec("name", "名称", .TEXT),
        FSpec("type", "类型", .SELECT, ["科技", "魔法", "装备", "农业", "美化", "建筑", "实用", "娱乐", "其他"]),
        FSpec("loader", "加载器", .SELECT, ["Forge", "Fabric"]),
    ],
    "singer_famous": [
        FSpec("name", "歌手名称", .TEXT),
        FSpec("language", "语言", .SELECT, ["华语", "粤语", "日语", "韩语", "英语", "其他"]),
        FSpec("gender", "性别", .SELECT, ["男", "女", "组合"]),
        FSpec("type", "流派", .TEXT),
        FSpec("fame", "知名度 ≥", .RANGE),
    ],
    "daily_song": [
        FSpec("singer", "歌手", .TEXT),
        FSpec("score", "分数 ≥", .NUMBER_MIN),
    ],
    "my_best": [
        FSpec("listName", "榜单搜索", .TEXT),
        FSpec("type", "类型", .SELECT, ["游戏", "电影", "音乐", "动漫", "书籍", "美食", "其他"]),
    ],
    "online_mood": [
        FSpec("type", "类型", .SELECT, ["局域网", "网游", "同屏", "服务器"]),
    ],
    "hobby_journey": [
        FSpec("frequency", "频率", .SELECT, ["自由", "每天", "每周", "每月"]),
    ],
    "yisa_game": [
        FSpec("mode", "模式", .SELECT, ["普通", "困难", "贪婪", "贪婪+", "挑战", "每日", "虚空"]),
    ],
    "miao_game": [
        FSpec("profession", "职业", .SELECT, ["战士", "坦克", "猎人", "法师"]),
    ],
    "lucky_draw": [
        FSpec("mode", "模式", .SELECT, ["even", "weighted"]),
    ],
    "standalone_appreciation": [
        FSpec("type", "类型", .TEXT),
    ],
]

// ====== 小工具：Json 取值展示（org.json JSONObject.opt(...) 的等价）======

/// 取字段展示文本；缺失 / null / 空串返回 nil（与安卓 value != null && isNotEmpty && != "null" 一致）
private func jsonValueText(_ row: Json, _ key: String) -> String? {
    guard let v = row[key], !(v is NSNull) else { return nil }
    let s = jsonToString(v)
    if s.isEmpty || s == "null" { return nil }
    return s
}

/// 任意 JSON 值 → 字符串（布尔回 true/false，与 Java toString 一致）
private func jsonToString(_ v: Any) -> String {
    if let s = v as? String { return s }
    if let n = v as? NSNumber {
        // JSONSerialization 的布尔是 CFBoolean（objCType == "c"）
        if String(cString: n.objCType) == "c" { return n.boolValue ? "true" : "false" }
        return n.stringValue
    }
    if v is NSNull { return "null" }
    return String(describing: v)
}

/// 字段值展示：有下拉选项时把码值翻成中文标签（true/false → 是/否）
private func optionAwareValue(_ row: Json, _ field: FeatureField) -> String? {
    guard let raw = jsonValueText(row, field.key) else { return nil }
    guard !field.options.isEmpty else { return raw }
    if field.options.contains(raw) { return raw }
    if raw == "true" || raw == "false" {
        let cn = raw == "true" ? "是" : "否"
        if field.options.contains(cn) { return cn }
    }
    return raw
}

// ====== 功能 Tab：九宫格入口 ======

struct FeaturesTab: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    /// Q-6：宽屏多列（手机 3 列；宽屏左侧 92pt 导航栏要扣掉）
    private var columns: Int {
        let width = UIScreen.main.bounds.width
        let content = width >= 600 ? width - 92 : width
        if content >= 900 { return 6 }
        if content >= 700 { return 5 }
        if content >= 520 { return 4 }
        return 3
    }

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns),
                spacing: 10
            ) {
                ForEach(FEATURE_CATALOG) { def in
                    FeatureGridCell(emoji: def.emoji, title: def.title) {
                        vm.pushOverlay(.featureList(appType: def.appType, title: def.title))
                    }
                }
                // P2-3：各类排行（全站金币 / 消费 / 签到榜）
                FeatureGridCell(emoji: "🥇", title: "排行榜") {
                    vm.pushOverlay(.leaderboard)
                }
                // P3-2：游戏厅（网页游戏统一进手机 WebView 容器）
                FeatureGridCell(emoji: "🎮", title: "游戏厅") {
                    vm.pushOverlay(.gameCenter)
                }
            }
            .padding(14)
        }
        .background(palette.background)
    }
}

private struct FeatureGridCell: View {
    let emoji: String
    let title: String
    let action: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(palette.primaryContainer)
                    )
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.onBackground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
                    .shadow(color: .black.opacity(0.07), radius: 1, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ====== P2 通用只读列表（覆盖层）======

struct FeatureListScreen: View {
    let appType: String
    let title: String

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    /// 网站同款过滤条件（实时生效）
    @State private var filterValues: [String: String] = [:]
    /// 用户下拉（"" = 全部用户）
    @State private var userFilter: String = ""
    @State private var filterOpen = false

    private var def: FeatureDef { featureDefOf(appType) }
    private var specs: [FSpec] { FEATURE_FILTERS[appType] ?? [] }

    private var filtered: [Json] {
        vm.featureRows.filter { row in
            let userOk: Bool
            if userFilter.isEmpty {
                userOk = true
            } else if let fid = Int(userFilter) {
                userOk = row.optLong("userId", -1) == fid
            } else {
                userOk = false
            }
            guard userOk else { return false }
            return specs.allSatisfy { sp in
                guard let v = filterValues[sp.key], !v.isEmpty else { return true }
                switch sp.kind {
                case .RANGE:
                    return row.optInt(sp.key, -1) >= (Int(v) ?? 0)
                case .NUMBER_MIN:
                    return row.optDouble(sp.key, -1.0) >= (Double(v) ?? 0.0)
                case .TEXT, .SELECT:
                    return row.optString(sp.key) == v
                }
            }
        }
    }

    var body: some View {
        OverlayScaffold(title: title) {
            VStack(spacing: 0) {
                filterBar
                if filterOpen && !specs.isEmpty {
                    filterPanel
                }
                stateContent
            }
        }
        // P2-1：记一笔 FAB（除只读榜单外都能新增）
        .overlay(alignment: .bottomTrailing) { fab }
        .onAppear { vm.loadUsers() }
    }

    // ---- 过滤条：条数 + 用户下拉 + 筛选开关 ----

    private var filterBar: some View {
        HStack(spacing: 8) {
            Text("共 \(filtered.count) 条")
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker(userFilterLabel, selection: $userFilter) {
                Text("全部用户").tag("")
                ForEach(vm.users.keys.sorted(), id: \.self) { id in
                    Text(vm.users[id] ?? "用户\(id)").tag("\(id)")
                }
            }
            .pickerStyle(.menu)
            .font(.system(size: 12))
            .tint(palette.onSurfaceVariant)
            .frame(maxWidth: 150, minHeight: 44)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(filterValues.isEmpty ? palette.outline : palette.primary)
            )

            Button {
                filterOpen.toggle()
            } label: {
                Text(filterOpen ? "收起" : ("筛选" + (filterValues.isEmpty ? "" : " ●")))
                    .font(.system(size: 12))
                    .foregroundStyle(filterValues.isEmpty ? palette.onSurfaceVariant : palette.primary)
                    .frame(minWidth: 60, minHeight: 44)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(filterValues.isEmpty ? palette.outline : palette.primary)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var userFilterLabel: String {
        if userFilter.isEmpty { return "全部用户" }
        if let id = Int(userFilter), let name = vm.users[id] { return name }
        return "全部用户"
    }

    // ---- 筛选面板（网站同款控件）----

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(specs) { sp in
                switch sp.kind {
                case .TEXT:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sp.label)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                        TextField(sp.label, text: textBinding(sp.key))
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(palette.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(palette.outline)
                                    )
                            )
                    }
                    .padding(.vertical, 3)

                case .SELECT:
                    HStack(spacing: 8) {
                        Text(sp.label)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(width: 76, alignment: .leading)
                        Picker(selectLabel(sp), selection: selectBinding(sp.key)) {
                            Text("全部").tag("")
                            ForEach(sp.options, id: \.self) { opt in
                                Text(opt).tag(opt)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(size: 12))
                        .tint(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(palette.outline)
                        )
                    }
                    .padding(.vertical, 3)

                case .NUMBER_MIN:
                    VStack(alignment: .leading, spacing: 3) {
                        Text(sp.label + "（≥）")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                        TextField(sp.label, text: textBinding(sp.key))
                            .font(.system(size: 13))
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(palette.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(palette.outline)
                                    )
                            )
                    }
                    .padding(.vertical, 3)

                case .RANGE:
                    HStack(spacing: 8) {
                        Text(sp.label)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(width: 76, alignment: .leading)
                        Slider(value: rangeBinding(sp.key), in: 0...10, step: 1)
                            .tint(palette.primary)
                        Text("\(Int(Double(filterValues[sp.key] ?? "0") ?? 0))")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onBackground)
                            .frame(width: 28)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 3)
                }
            }

            HStack {
                Spacer()
                Button {
                    filterValues = [:]
                } label: {
                    Text("重置")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(palette.surface)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    private func selectLabel(_ sp: FSpec) -> String {
        let v = filterValues[sp.key] ?? ""
        return v.isEmpty ? "全部" : v
    }

    private func textBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { filterValues[key] ?? "" },
            set: { filterValues[key] = $0 }
        )
    }

    private func selectBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { filterValues[key] ?? "" },
            set: { filterValues[key] = $0 }
        )
    }

    private func rangeBinding(_ key: String) -> Binding<Double> {
        Binding(
            get: { Double(filterValues[key] ?? "0") ?? 0 },
            set: { filterValues[key] = String(Int($0)) }
        )
    }

    // ---- 三态：骨架 / 失败 / 空 / 列表 ----

    @ViewBuilder
    private var stateContent: some View {
        if vm.featureLoading && filtered.isEmpty {
            // Q-1：加载中 → 骨架屏
            SkeletonCards(count: 5)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .top)
        } else if filtered.isEmpty && vm.listError != nil {
            // Q-3：失败 → 说明 + 重试
            ErrorState(message: vm.listError ?? "加载失败") {
                vm.loadFeatureList(appType)
            }
        } else if filtered.isEmpty {
            Text("暂无记录，点右上角 ＋ 记一笔")
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 120)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(filtered.indices, id: \.self) { i in
                    let row = filtered[i]
                    FeatureRowCard(row: row, def: def) {
                        vm.pushOverlay(.featureDetail(appType: appType, row: row))
                    }
                }
                LoadMoreEffect(hasMore: vm.featureHasMore, loading: vm.loadingMore) {
                    vm.moreFeatureList()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    // ---- 记一笔 FAB ----

    @ViewBuilder
    private var fab: some View {
        if appType != "my_best" {
            Button {
                vm.pushOverlay(.featureEdit(appType: appType, title: def.title, row: nil))
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
}

// ====== 记录行卡片 ======

private struct FeatureRowCard: View {
    let row: Json
    let def: FeatureDef
    let onClick: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        // P2-3：榜单类用专属卡片（榜单名 + 冠亚季军），其余仍是通用只读卡片
        if def.appType == "my_best" {
            MyBestCard(row: row, onClick: onClick)
        } else {
            generalCard
        }
    }

    private var generalCard: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(def.emoji)
                        .font(.system(size: 16))
                    Text(firstValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.onSurfaceVariant)
                }

                ForEach(Array(def.fields.dropFirst())) { field in
                    if let v = optionAwareValue(row, field) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(field.label)
                                .font(.system(size: 12))
                                .foregroundStyle(palette.onSurfaceVariant)
                            Text(v)
                                .font(.system(size: 13))
                                .foregroundStyle(palette.onSurfaceVariant)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(palette.surface)
                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var firstValue: String {
        guard let first = def.fields.first else { return "—" }
        return optionAwareValue(row, first) ?? "—"
    }
}

// ====== P2-3：我的最佳 —— 榜单专属卡片（冠亚季军一眼可见）======

struct MyBestCard: View {
    let row: Json
    var onClick: (() -> Void)? = nil
    @Environment(\.palette) var palette

    var body: some View {
        if let onClick {
            Button(action: onClick) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("🏆")
                    .font(.system(size: 16))
                Text(listName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if onClick != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
            }

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.top, 4)

            Group {
                if topItems.isEmpty {
                    Text("还没有排进名次")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .padding(.top, 10)
                } else {
                    VStack(spacing: 4) {
                        ForEach(topItems.indices, id: \.self) { index in
                            let item = topItems[index]
                            HStack(spacing: 8) {
                                Text(["🥇", "🥈", "🥉"][index])
                                    .font(.system(size: 14))
                                Text(item.optString("rankName").isEmpty ? "—" : item.optString("rankName"))
                                    .font(.system(size: 14))
                                    .foregroundStyle(palette.onBackground)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                let score = item.optString("score")
                                if !score.isEmpty && score != "null" {
                                    Text(score)
                                        .font(.system(size: 13))
                                        .foregroundStyle(palette.onSurfaceVariant)
                                }
                            }
                        }
                    }
                    .padding(.top, 10)
                }
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

    private var listName: String {
        let n = row.optString("listName")
        return n.isEmpty ? "未命名榜单" : n
    }

    private var subtitle: String {
        let type = row.optString("type")
        let importance = row.optString("importance")
        var parts: [String] = []
        if !type.isEmpty { parts.append(type) }
        if !importance.isEmpty { parts.append("重要度 \(importance)") }
        let joined = parts.joined(separator: " · ")
        return joined.isEmpty ? "我的榜单" : joined
    }

    private var topItems: [Json] {
        (row.optJSONArray("items")?.objects() ?? [])
            .sorted { $0.optInt("rank", Int.max) < $1.optInt("rank", Int.max) }
            .prefix(3)
            .map { $0 }
    }
}

// ====== 功能记录详情（点击卡片进入）======

struct FeatureDetailScreen: View {
    let appType: String
    let row: Json

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var showDelete = false

    private var def: FeatureDef { featureDefOf(appType) }

    /// 只读 vs 可编辑（P2-5）：本人的记录才有编辑/删除；榜单类固定只读
    private var editable: Bool {
        appType != "my_best" &&
            row["userId"] != nil &&
            row.optLong("userId", -1) == vm.userId
    }

    var body: some View {
        OverlayScaffold(title: def.title + " · 详情", trailing: trailing) {
            LazyVStack(spacing: 8) {
                if appType == "my_best" {
                    MyBestCard(row: row)
                    if row["userId"] != nil || row["createdAt"] != nil {
                        metaCard
                    }
                } else {
                    detailCard
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .alert("删除这条记录？", isPresented: $showDelete) {
            Button("删除", role: .destructive) {
                let id = row.optLong("id")
                if id > 0 {
                    vm.deleteFeature(appType: appType, id: id)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复")
        }
    }

    private var trailing: AnyView? {
        if editable {
            return AnyView(
                HStack(spacing: 2) {
                    Button {
                        vm.pushOverlay(.featureEdit(appType: appType, title: def.title, row: row))
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.primary)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDelete = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(palette.onErrorContainer)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            )
        }
        // 只读标记：一眼能看出这条不能改
        return AnyView(
            Text("🔒 只读")
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.trailing, 6)
        )
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(def.emoji)
                    .font(.system(size: 20))
                Text(headerTitle)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(def.fields) { f in
                    if let v = optionAwareValue(row, f) {
                        HStack(alignment: .top, spacing: 8) {
                            Text(f.label)
                                .font(.system(size: 13))
                                .foregroundStyle(palette.onSurfaceVariant)
                                .frame(width: 84, alignment: .leading)
                            Text(v)
                                .font(.system(size: 14))
                                .foregroundStyle(palette.onBackground)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if row["userId"] != nil {
                Text("记录者：" + vm.userName(row.optLong("userId")))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            if row["createdAt"] != nil {
                Text("时间：" + String(row.optString("createdAt").replacingOccurrences(of: "T", with: " ").prefix(16)))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
        )
    }

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            if row["userId"] != nil {
                Text("记录者：" + vm.userName(row.optLong("userId")))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            if row["createdAt"] != nil {
                Text("时间：" + String(row.optString("createdAt").replacingOccurrences(of: "T", with: " ").prefix(16)))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
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

    private var headerTitle: String {
        guard let first = def.fields.first else { return def.title }
        let v = row.optString(first.key)
        return v.isEmpty ? def.title : v
    }
}
