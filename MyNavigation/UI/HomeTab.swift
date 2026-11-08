import SwiftUI

// ====== 首页：签到渐变条 + 「日常 / 专栏 / 动态」三栏（HomeTab.kt 对齐）======

struct HomeTab: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        VStack(spacing: 0) {
            checkInBar
            feedTabs
            feed
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .onAppear {
            vm.refreshHome()
            vm.loadUsers()
        }
    }

    // MARK: - 签到细条（已签 / 未签两态）

    @MainActor
    private var checkInBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundStyle(palette.onPrimary)

            Text(vm.checkedIn
                 ? "今日已签到 · 连续 \(vm.checkInStreak) 天"
                 : "连续 \(vm.checkInStreak) 天 · 今天还没打卡")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(palette.onPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)

            if vm.checkedIn {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(palette.onPrimary)
            } else {
                Button {
                    vm.doCheckIn()
                } label: {
                    Text("签到")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 34)
                        .background(Capsule().fill(palette.onPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [palette.primary, palette.primary.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 胶囊分段：日常 / 专栏 / 动态

    @MainActor
    private var feedTabs: some View {
        HStack(spacing: 6) {
            ForEach(HomeFeed.allCases) { f in
                let selected = vm.homeFeed == f
                Button {
                    vm.setHomeFeed(f)
                } label: {
                    Text(f.label)
                        .font(.system(size: 13, weight: selected ? .bold : .medium))
                        .foregroundStyle(selected ? palette.primary : palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(selected ? palette.primaryContainer : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(palette.surface)
    }

    @MainActor
    @ViewBuilder
    private var feed: some View {
        switch vm.homeFeed {
        case .daily: DailyFeedView()
        case .column: ColumnFeedView()
        case .dynamic: DynamicFeedView()
        }
    }
}

// MARK: - 日常流（两列卡片网格）

private struct DailyFeedView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    private let gridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        if vm.homeDailies.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    LazyVGrid(columns: gridColumns, spacing: 10) {
                        ForEach(vm.homeDailies) { item in
                            DailyTweetCard(item: item)
                        }
                    }
                    if vm.dailyHasMore {
                        Text("上滑加载更多…")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    LoadMoreEffect(hasMore: vm.dailyHasMore, loading: vm.loadingMore) {
                        vm.moreDailies()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 96)
            }
        }
    }

    // 骨架 / 失败 / 空三态（Q-1 / Q-3）
    @MainActor
    @ViewBuilder
    private var emptyState: some View {
        if vm.homeLoading {
            SkeletonCards(count: 4)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if let err = vm.listError {
            ErrorState(message: err, retry: { vm.refreshHome() })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyState(emoji: "🍃", text: "还没有日常，点右下角发一条吧")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - 单条日常卡片

private struct DailyPhoto: Identifiable {
    let id: Int
    /// resolveImg 之后的绝对地址
    let url: String
    let media: MediaItem
}

private struct DailyTweetCard: View {
    let item: DailyItem
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var expanded = false

    private let foldLimit = 2000

    @MainActor
    private var author: String { displayAuthor(item, vm) }

    @MainActor
    private var photos: [DailyPhoto] {
        let source = Array(item.images.prefix(6))
        var result: [DailyPhoto] = []
        for (i, u) in source.enumerated() {
            result.append(
                DailyPhoto(
                    id: item.id * 100 + i,
                    url: resolveImg(u),
                    media: MediaItem(
                        id: item.id * 100 + i,
                        name: "日常配图",
                        url: u,
                        by: displayAuthor(item, vm),
                        tags: "",
                        score: 0
                    )
                )
            )
        }
        return result
    }

    private var foldedContent: String {
        let text = item.content
        if text.count > foldLimit && !expanded {
            return String(text.prefix(foldLimit)) + "…"
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text(String(author.first ?? "薇"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(palette.primaryContainer))

                VStack(alignment: .leading, spacing: 2) {
                    Text(author)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                    Text(shortTimeText(item.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !item.title.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(item.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .lineLimit(2)
                    .padding(.top, 8)
            }

            if !item.content.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(foldedContent)
                    .font(.system(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(palette.onBackground.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                if item.content.count > foldLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
                    } label: {
                        Text(expanded ? "收起" : "展开全文（共 \(item.content.count) 字）")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.primary)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !item.images.isEmpty {
                let list = photos
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6),
                    ],
                    spacing: 6
                ) {
                    ForEach(list.indices, id: \.self) { idx in
                        let photo = list[idx]
                        SmartImage(url: photo.url)
                            .frame(height: 84)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                vm.pushOverlay(.mediaViewer(items: list.map(\.media), index: idx))
                            }
                    }
                }
                .padding(.top, 8)
            }

            let tags = Array(item.tags
                .split(whereSeparator: { $0.isWhitespace })
                .map { String($0) }
                .filter { !$0.isEmpty }
                .prefix(4))
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(palette.primaryContainer.opacity(0.5))
                            )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.surface))
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
    }
}

// MARK: - 专栏流

private struct ColumnFeedView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        if vm.columns.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(vm.columns.indices, id: \.self) { i in
                        ColumnCard(col: vm.columns[i])
                    }
                    if vm.columnHasMore {
                        Text("上滑加载更多…")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    LoadMoreEffect(hasMore: vm.columnHasMore, loading: vm.loadingMore) {
                        vm.moreColumns()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 96)
            }
        }
    }

    @MainActor
    @ViewBuilder
    private var emptyState: some View {
        if vm.columnLoading {
            SkeletonCards(count: 3)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else {
            EmptyState(emoji: "📰", text: "还没有专栏，点右下角写一篇")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// 专栏卡片：自己的文章带编辑按钮（只能编辑自己的）
private struct ColumnCard: View {
    let col: Json
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @MainActor
    private var mine: Bool { col.optLong("userId") == vm.userId }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(col.optString("type").isEmpty ? "专栏" : col.optString("type"))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(palette.primaryContainer))

                Text(col.optString("title", "无标题"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if mine {
                    Button {
                        vm.pushOverlay(
                            .composeColumn(
                                id: col.optLong("id"),
                                title: col.optString("title"),
                                content: col.optString("content"),
                                type: col.optString("type", "其他")
                            )
                        )
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(palette.primary)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surfaceVariant.opacity(0.6)))
                    }
                    .buttonStyle(.plain)
                }
            }

            let plain = htmlToPlain(col.optString("content"), max: 140)
            if !plain.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(plain)
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .foregroundStyle(palette.onBackground.opacity(0.85))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)
            }

            HStack {
                Text(vm.userName(col.optLong("userId")))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(absFeedTime(col.optString("createdAt")))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .padding(.top, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(palette.surface))
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
        .contentShape(Rectangle())
        .onTapGesture {
            vm.pushOverlay(.columnDetail(col: col))
        }
    }
}

// MARK: - 动态流（分批 15 条展示）

private struct DynamicFeedView: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @MainActor
    private var visible: [ActivityItem] { Array(vm.dynamics.prefix(vm.dynamicsShown)) }
    @MainActor
    private var hasMore: Bool { vm.dynamicsShown < vm.dynamics.count }

    var body: some View {
        if visible.isEmpty {
            Text("暂无最近更新")
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(visible) { item in
                        DynamicCard(item: item)
                    }
                    if hasMore {
                        Text("上滑加载更多…")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    LoadMoreEffect(hasMore: hasMore, loading: vm.loadingMore) {
                        vm.moreDynamics()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 96)
            }
        }
    }
}

private struct DynamicCard: View {
    let item: ActivityItem
    @Environment(\.palette) var palette

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(String(item.userName.first ?? "友"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.onSecondaryContainer)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.secondaryContainer))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.userName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)

                    Text(appTypeName(item.appType))
                        .font(.system(size: 10))
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(palette.primaryContainer))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Text(absFeedTime(item.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(palette.onSurfaceVariant)
                }

                Text(item.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onBackground.opacity(0.85))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
    }
}

// MARK: - 小工具

/// 作者显示：服务端 authorName 优先，否则查用户表纠正「用户123」（displayAuthor 对齐）
@MainActor
private func displayAuthor(_ item: DailyItem, _ vm: AppViewModel) -> String {
    let name = item.authorName
    if !name.trimmingCharacters(in: .whitespaces).isEmpty && !name.hasPrefix("用户") { return name }
    if name.hasPrefix("用户"), let uid = Int(String(name.dropFirst("用户".count))), uid > 0 {
        let mapped = vm.userName(uid)
        if !mapped.hasPrefix("用户") { return mapped }
    }
    return name.isEmpty ? "站友" : name
}

/// 安卓原文：createdAt.replace('T', ' ').take(16)（专栏 / 动态卡片沿用）
private func absFeedTime(_ raw: String) -> String {
    String(raw.replacingOccurrences(of: "T", with: " ").prefix(16))
}

/// 时间：7 天内相对显示（时间相对显示），更早的与安卓一致（T → 空格，取 16 位）
private func shortTimeText(_ raw: String) -> String {
    let flat = raw.replacingOccurrences(of: "T", with: " ")
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "zh_CN")
    if let date = formatter.date(from: flat) {
        let delta = Date().timeIntervalSince(date)
        if delta >= 0 {
            if delta < 60 { return "刚刚" }
            if delta < 3600 { return "\(Int(delta / 60)) 分钟前" }
            if delta < 86_400 { return "\(Int(delta / 3600)) 小时前" }
            if delta < 7 * 86_400 { return "\(Int(delta / 86_400)) 天前" }
        }
    }
    return String(flat.prefix(16))
}
