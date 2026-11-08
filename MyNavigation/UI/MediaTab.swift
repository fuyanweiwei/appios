import SwiftUI

// ====== 媒记（对照 Android ui/MediaTab.kt）======
// 梗图 / 壁纸 / 绘画 / 小说 四子栏 + 下拉过滤 + 图片网格 + 小说列表
// 点图 → MediaViewer；点小说 → NovelDetail（复用覆盖层）

@MainActor struct MediaTab: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var filterOpen = false

    private var section: MediaSection { vm.mediaSection }
    private var sectionFilters: [String: String] { vm.mediaFiltersOf(section) }

    /// 小说服务端只认 level，其余条件不计数
    private var applicableKeys: Set<String> {
        section == .novels ? ["level"] : ["name", "tags", "drawer", "score", "level"]
    }

    private var activeCount: Int {
        sectionFilters.filter { entry in
            applicableKeys.contains(entry.key) &&
                !entry.value.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            sectionBar
            filterBar
            if filterOpen {
                MediaFilterPanel(section: section, filters: sectionFilters)
            }
            GeometryReader { geo in
                if section == .novels {
                    novelList
                } else {
                    mediaGrid(width: geo.size.width)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .onAppear { firstLoad() }
    }

    // ====== 子栏：梗图 / 壁纸 / 绘画 / 小说 ======

    private var sectionBar: some View {
        HStack(spacing: 0) {
            ForEach(MediaSection.allCases) { sec in
                Button {
                    vm.switchMediaSection(sec)
                } label: {
                    Text(sec.label)
                        .font(.system(size: 14, weight: section == sec ? .bold : .medium))
                        .foregroundStyle(section == sec ? palette.primary : palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .background(palette.surface)
    }

    // ====== 过滤条：条数 + 重置 + 过滤/收起 ======

    @MainActor
    private var filterBar: some View {
        let total = section == .novels ? vm.novels.count : vm.mediaItems.count
        return HStack(spacing: 6) {
            Text("共 \(total) 条" + (activeCount > 0 ? " · 已过滤 \(activeCount) 项" : ""))
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            if activeCount > 0 {
                Button {
                    vm.clearMediaFilters(section)
                } label: {
                    Text("重置")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.outline))
                }
                .buttonStyle(.plain)
            }

            Button {
                filterOpen.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12))
                    Text(filterOpen ? "收起" : "过滤")
                        .font(.system(size: 12))
                }
                .foregroundStyle(activeCount > 0 ? palette.primary : palette.onSurfaceVariant)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(activeCount > 0 ? palette.primary : palette.outline))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // ====== 首次进入自动加载当前分区 ======

    @MainActor
    private func firstLoad() {
        DiagTrace.step("媒记:进入Tab 当前=\(section.label)")
        if section == .novels {
            if vm.novels.isEmpty { vm.loadNovels() }
        } else if vm.mediaItems.isEmpty && !vm.mediaLoading {
            vm.loadMedia(refresh: true)
        }
    }

    // ====== 图片区（三态 + 网格 + 加载更多）======

    @MainActor
    @ViewBuilder
    private func mediaGrid(width: CGFloat) -> some View {
        // Q-6：宽屏多列（手机 2 列，逐步加宽）
        let columnCount = width >= 900 ? 5 : (width >= 700 ? 4 : (width >= 520 ? 3 : 2))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)

        if vm.mediaItems.isEmpty {
            if vm.mediaLoading {
                mediaGridSkeleton(columns: columns)
            } else if let err = vm.mediaError {
                ErrorState(message: err) { vm.loadMedia(refresh: true) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(emoji: "🖼️", text: "暂无\(section.label)，换个过滤条件试试")
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(vm.mediaItems.indices, id: \.self) { i in
                        mediaCell(vm.mediaItems[i], index: i)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                if vm.mediaHasMore {
                    Text("上滑加载更多…")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                LoadMoreEffect(hasMore: vm.mediaHasMore, loading: vm.loadingMore) {
                    vm.loadMedia(refresh: false)
                }
                .padding(.bottom, 96)
            }
        }
    }

    @ViewBuilder
    private func mediaGridSkeleton(columns: [GridItem]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<12, id: \.self) { _ in
                    SkeletonBox(cornerRadius: 12)
                        .aspectRatio(1.25, contentMode: .fit)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
    }

    @MainActor
    private func mediaCell(_ item: MediaItem, index: Int) -> some View {
        Button {
            DiagTrace.step("媒记:点开查看 \(item.name) (#\(index)/\(vm.mediaItems.count))")
            vm.pushOverlay(.mediaViewer(items: vm.mediaItems, index: index))
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    SmartImage(url: resolveImg(item.url))
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                    if item.level > 0 {
                        levelBadge(item.level)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name.trimmingCharacters(in: .whitespaces).isEmpty ? "无名" : item.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(item.score > 0 ? String(repeating: "★", count: max(0, item.score)) : "☆☆☆☆☆")
                            .font(.system(size: 10))
                            .foregroundStyle(item.score > 0 ? palette.primary : palette.onSurfaceVariant)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if !item.by.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(item.by)
                                .font(.system(size: 10))
                                .foregroundStyle(palette.onSurfaceVariant)
                                .lineLimit(1)
                                .frame(width: 56, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }

    /// 分级角标（服务端已按成人配置过滤，这里仅提示）
    private func levelBadge(_ level: Int) -> some View {
        let text = level == 1 ? "12+" : (level == 2 ? "18+" : "21+")
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(palette.onErrorContainer)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 4).fill(palette.errorContainer))
            .padding(4)
    }

    // ====== 小说列表（三态 + 卡片 + 加载更多）======

    @MainActor
    @ViewBuilder
    private var novelList: some View {
        ScrollView {
            if vm.novels.isEmpty {
                if vm.mediaLoading {
                    SkeletonCards(count: 5)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                } else if let err = vm.mediaError {
                    ErrorState(message: err) { vm.loadNovels() }
                } else {
                    EmptyState(emoji: "📖", text: "暂无小说")
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(vm.novels) { novel in
                        NovelCard(novel: novel) {
                            vm.pushOverlay(.novelDetail(novelId: novel.id, title: novel.title))
                        }
                    }
                    if vm.novelHasMore {
                        Text("上滑加载更多…")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                    }
                    LoadMoreEffect(hasMore: vm.novelHasMore, loading: vm.loadingMore) {
                        vm.moreNovels()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
        }
    }
}

// MARK: - 过滤面板（文本 600ms 防抖，选项点选即生效）

@MainActor private struct MediaFilterPanel: View {
    let section: MediaSection
    let filters: [String: String]
    @Environment(\.palette) var palette

    private var scoreOptions: [(String, String)] {
        [("", "不限")] + (1...5).map { ("\($0)", String(repeating: "★", count: $0)) }
    }

    private var levelOptions: [(String, String)] {
        [("", "不限"), ("0", "全年龄"), ("1", "12+"), ("2", "18+"), ("3", "21+")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if section != .novels {
                MediaFilterField(section: section, key: "name", label: "名称", filters: filters)
                MediaFilterField(section: section, key: "tags", label: "标签", filters: filters)
                MediaFilterField(section: section, key: "drawer", label: "画师 / 创作者", filters: filters)
                MediaSelectField(section: section, key: "score", label: "评分", options: scoreOptions, filters: filters)
            }
            MediaSelectField(section: section, key: "level", label: "分级", options: levelOptions, filters: filters)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(palette.isDark ? 0.3 : 0.08), radius: 2, y: 1)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

/// 文本过滤项：停止输入 0.6s 自动回第 0 页重拉（防抖，避免每敲一个字打一次接口）
@MainActor private struct MediaFilterField: View {
    let section: MediaSection
    let key: String
    let label: String
    let filters: [String: String]
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var text = ""
    @State private var seq = 0

    var body: some View {
        TextField(label, text: $text)
            .font(.system(size: 13))
            .foregroundStyle(palette.onBackground)
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(palette.surface)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.outline))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.vertical, 3)
            .onAppear { text = filters[key] ?? "" }
            .onChange(of: filters[key]) { _, newValue in
                let v = newValue ?? ""
                if text != v { text = v }
            }
            .onChange(of: text) { _, newValue in
                guard newValue != (filters[key] ?? "") else { return }
                seq += 1
                let mine = seq
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    // 防抖期间又被改回去 / 已经同步过，就不打了
                    guard mine == seq, text == newValue else { return }
                    var next = filters
                    if newValue.isEmpty {
                        next.removeValue(forKey: key)
                    } else {
                        next[key] = newValue
                    }
                    vm.setMediaFilters(section, next)
                }
            }
    }
}

/// 下拉选项过滤项（评分 / 分级）：点选即生效
@MainActor private struct MediaSelectField: View {
    let section: MediaSection
    let key: String
    let label: String
    let options: [(String, String)]
    let filters: [String: String]
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    private var current: String { filters[key] ?? "" }

    private var currentLabel: String {
        options.first(where: { $0.0 == current })?.1 ?? "不限"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(palette.onBackground)
                .frame(width: 78, alignment: .leading)

            Menu {
                ForEach(options.indices, id: \.self) { i in
                    let value = options[i].0
                    Button(options[i].1) {
                        guard value != current else { return }
                        var next = filters
                        if value.isEmpty {
                            next.removeValue(forKey: key)
                        } else {
                            next[key] = value
                        }
                        vm.setMediaFilters(section, next)
                    }
                }
            } label: {
                Text(currentLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.outline))
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - 小说卡片

@MainActor private struct NovelCard: View {
    let novel: NovelBrief
    let onOpen: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 10) {
                SmartImage(url: resolveImg(novel.cover))
                    .frame(width: 56, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(novel.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                    Text("\(novel.author.isEmpty ? "匿名" : novel.author) · \(mediaFormatWords(novel.words)) · \(novel.reads) 阅读")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .lineLimit(1)
                    if !novel.intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(novel.intro)
                            .font(.system(size: 12))
                            .foregroundStyle(palette.onBackground.opacity(0.8))
                            .lineLimit(2)
                            .padding(.top, 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

/// 字数文案（与安卓 formatWords 对齐）
private func mediaFormatWords(_ w: Int) -> String {
    if w >= 10000 {
        return String(format: "%.1f 万字", Double(w) / 10000.0)
    } else if w > 0 {
        return "\(w) 字"
    } else {
        return "字数未知"
    }
}
