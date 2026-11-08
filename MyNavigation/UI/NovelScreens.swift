import SwiftUI
import UIKit

// ====== P1 小说（对照 Android ui/NovelScreens.kt）======
// NovelDetailScreen：封面 / 简介 + 章节目录（分批 30 条）
// NovelReaderScreen：正文 + 字号 A−/A+ + 🌙夜间 + 进度记忆 + 上/下一章

// MARK: - 小说详情（章节目录）

@MainActor struct NovelDetailScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var chaptersShown = 30

    private var novelId: Int? {
        if case let .novelDetail(id, _)? = vm.overlays.last { return id }
        return nil
    }

    var body: some View {
        OverlayScaffold(title: vm.novelDetail?.novel.title ?? "小说") {
            detailContent
        }
        .onAppear {
            if let id = novelId, vm.novelDetail == nil, !vm.detailLoading {
                vm.loadNovelDetail(id)
            }
        }
        .onChange(of: vm.novelDetail?.novel.id) { _, _ in
            chaptersShown = 30
        }
    }

    // 骨架 / 失败 / 正常
    @ViewBuilder
    private var detailContent: some View {
        if vm.detailLoading && vm.novelDetail == nil {
            SkeletonCards(count: 4)
                .padding(.horizontal, 16)
                .padding(.top, 12)
        } else if let d = vm.novelDetail {
            detailBody(d)
        } else {
            ErrorState(message: vm.listError ?? "章节加载失败") {
                if let id = novelId { vm.loadNovelDetail(id) }
            }
        }
    }

    private func detailBody(_ d: NovelDetailData) -> some View {
        let visible = Array(d.chapters.prefix(chaptersShown))
        let chapterHasMore = chaptersShown < d.chapters.count
        return LazyVStack(alignment: .leading, spacing: 8) {
            // 简介卡：封面 + 标题 + 作者 / 字数 / 阅读 + 简介 + 继续阅读
            HStack(alignment: .top, spacing: 12) {
                SmartImage(url: resolveImg(d.novel.cover))
                    .frame(width: 84, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .clipped()

                VStack(alignment: .leading, spacing: 5) {
                    Text(d.novel.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(2)
                    Text("\(d.novel.author.isEmpty ? "匿名" : d.novel.author) · \(novelFormatWords(d.novel.words)) · \(d.novel.reads) 阅读")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                    if !d.novel.intro.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(d.novel.intro)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onBackground.opacity(0.85))
                    }
                    if let resume = resumeChapter(d) {
                        Button {
                            vm.pushOverlay(.novelReader(novelId: d.novel.id, chapterId: resume.id, title: resume.title))
                        } label: {
                            Text("继续阅读上次进度")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.onPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(palette.primary))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text("目录（\(d.chapters.count) 章）")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.onBackground)
                .padding(.top, 6)
                .padding(.bottom, 2)

            // 章节分批展示（每次 +30）
            ForEach(visible.indices, id: \.self) { i in
                chapterRow(novelId: d.novel.id, index: i, chapter: visible[i])
            }

            if chapterHasMore {
                Text("上滑加载更多…")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(12)
            }
            LoadMoreEffect(hasMore: chapterHasMore, loading: false) {
                chaptersShown = min(chaptersShown + 30, d.chapters.count)
            }
            .id("chapters-\(chaptersShown)")
        }
        .padding(14)
    }

    private func chapterRow(novelId: Int, index: Int, chapter: NovelChapterRef) -> some View {
        Button {
            vm.pushOverlay(.novelReader(novelId: novelId, chapterId: chapter.id, title: chapter.title))
        } label: {
            Text("\(index + 1). \(chapter.title.isEmpty ? "第\(index + 1)章" : chapter.title)")
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(palette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// 从阅读进度恢复：上次读的章节还在目录里就给个「继续阅读」
    private func resumeChapter(_ d: NovelDetailData) -> NovelChapterRef? {
        guard let saved = vm.getReaderProgress(d.novel.id), saved.chapterId > 0 else { return nil }
        return d.chapters.first { $0.id == saved.chapterId }
    }
}

// MARK: - 阅读器（P1-3）

@MainActor struct NovelReaderScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var fontScale: Double = 1
    @State private var night = false
    /// 滚动位置（普通类：写入不触发视图重绘，避免滚动时整屏刷新）
    @State private var scrollBox = ReaderScrollBox()
    @State private var initialOffset: CGFloat = 0
    @State private var restoreToken = 0
    @State private var novelId = 0
    @State private var chapterId = 0
    @State private var chapterTitle = "阅读"

    // 日间走 palette，夜间与安卓一致（黑底白字）
    private var bg: Color { night ? Color.black : palette.background }
    private var barBg: Color { night ? Color(hex: 0x121212) : palette.surface }
    private var fg: Color { night ? Color.white : palette.onBackground }
    private var dimFg: Color { night ? Color(hex: 0x9E9E9E) : palette.onSurfaceVariant }
    private var dividerColor: Color { night ? Color(hex: 0x333333) : palette.outlineVariant }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            mainBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bg.ignoresSafeArea())
        .onAppear { syncCurrent() }
        .onChange(of: vm.overlays.last) { _, _ in syncCurrent() }
        .onDisappear { saveProgress() }
    }

    @ViewBuilder
    private var mainBody: some View {
        if vm.detailLoading && vm.chapterContent == nil {
            // Q-1：正文加载中 → 骨架
            readerSkeleton
        } else if vm.chapterContent == nil && vm.listError != nil {
            // Q-3：正文加载失败 → 说明 + 重试
            ErrorState(message: vm.listError ?? "正文加载失败") {
                vm.loadChapter(chapterId)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                readerScroll
                Rectangle().fill(dividerColor).frame(height: 1)
                chapterBar
            }
        }
    }

    // ====== 顶栏：返回 + 标题 + A− / A+ + 夜间切换 ======

    private var topBar: some View {
        HStack(spacing: 2) {
            Button {
                vm.popOverlay()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fg)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Text(chapterTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(fg)
                .lineLimit(1)

            Spacer(minLength: 4)

            fontButton("A−") { adjustFont(-1) }
            fontButton("A+") { adjustFont(1) }

            Button {
                night.toggle()
                vm.setReaderNight(night)
            } label: {
                Text(night ? "☀" : "🌙")
                    .font(.system(size: 15))
                    .foregroundStyle(fg)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .frame(minHeight: 50)
        .background(barBg)
    }

    private func fontButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(fg)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    /// 字号 0.8 ~ 2.0，步进 0.1
    private func adjustFont(_ step: Int) {
        let tenths = (fontScale * 10).rounded()
        let next = min(20, max(8, tenths + Double(step)))
        fontScale = next / 10
        vm.setReaderFontScale(fontScale)
    }

    // ====== 正文 ======

    private var readerScroll: some View {
        ReaderScrollView(
            box: scrollBox,
            initialOffset: initialOffset,
            restoreToken: restoreToken,
            content: AnyView(
                ReaderBodyView(
                    text: readerText,
                    fontScale: fontScale,
                    fg: fg,
                    bg: bg
                )
            )
        )
    }

    private var readerText: AttributedString {
        let raw = vm.chapterContent ?? ""
        if looksLikeHtml(raw) { return htmlToAttributedString(raw) }
        return AttributedString(raw)
    }

    private var readerSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<9, id: \.self) { _ in
                SkeletonBox(cornerRadius: 6)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // ====== 底部翻章 ======

    private var chapterBar: some View {
        let chapters = vm.novelDetail?.chapters ?? []
        let idx = chapters.firstIndex(where: { $0.id == chapterId }) ?? -1
        let hasPrev = idx > 0
        let hasNext = idx >= 0 && idx < chapters.count - 1

        return HStack {
            Button {
                if hasPrev { goToChapter(idx - 1) }
            } label: {
                Text("‹ 上一章")
                    .font(.system(size: 14))
                    .foregroundStyle(hasPrev ? palette.primary : dimFg.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(!hasPrev)

            Button {
                if hasNext { goToChapter(idx + 1) }
            } label: {
                Text("下一章 ›")
                    .font(.system(size: 14))
                    .foregroundStyle(hasNext ? palette.primary : dimFg.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(!hasNext)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    /// 替换栈顶：先 pop 再 push（与安卓一致）
    private func goToChapter(_ index: Int) {
        guard let detail = vm.novelDetail, detail.chapters.indices.contains(index), novelId > 0 else { return }
        let ch = detail.chapters[index]
        saveProgress()
        vm.popOverlay()
        vm.pushOverlay(.novelReader(novelId: novelId, chapterId: ch.id, title: ch.title))
    }

    // ====== 当前章节定位 + 进度记忆 ======

    private func syncCurrent() {
        guard let last = vm.overlays.last, case let .novelReader(nId, cId, title) = last else {
            saveProgress()
            return
        }
        // 换章（替栈顶）时先把上一章的位置记下来
        if nId != novelId || cId != chapterId {
            saveProgress()
        }
        novelId = nId
        chapterId = cId
        chapterTitle = title
        fontScale = vm.getReaderFontScale()
        night = vm.getReaderNight()
        if let saved = vm.getReaderProgress(nId), saved.chapterId == cId, saved.offset > 0 {
            initialOffset = CGFloat(saved.offset)
        } else {
            initialOffset = 0
        }
        scrollBox.value = initialOffset
        restoreToken += 1
    }

    private func saveProgress() {
        guard novelId > 0, chapterId > 0 else { return }
        vm.saveReaderProgress(novelId: novelId, chapterId: chapterId, offset: Int(scrollBox.value))
    }
}

// MARK: - 正文渲染（不依赖 Environment：宿主在 UIScrollView 里）

private struct ReaderBodyView: View {
    let text: AttributedString
    let fontScale: Double
    let fg: Color
    let bg: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 16 * fontScale))
                .foregroundStyle(fg)
                .lineSpacing(5 * fontScale)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 28)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(bg)
    }
}

// MARK: - 可记忆进度的滚动容器（直接读写 contentOffset，进度精确）

private struct ReaderScrollView: UIViewRepresentable {
    let box: ReaderScrollBox
    var initialOffset: CGFloat
    var restoreToken: Int
    var content: AnyView

    func makeCoordinator() -> ReaderScrollCoordinator {
        ReaderScrollCoordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        ])

        context.coordinator.hosting = hosting
        context.coordinator.box = box
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.box = box
        context.coordinator.hosting?.rootView = content

        // 进度恢复：章节出现 / 进度刷新时按保存的 offset 复位（等一次布局后再定位）
        if context.coordinator.token != restoreToken {
            context.coordinator.token = restoreToken
            let target = initialOffset
            Task { @MainActor in
                scrollView.layoutIfNeeded()
                let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                let y = min(max(target, 0), maxOffset)
                guard abs(scrollView.contentOffset.y - y) > 0.5 else { return }
                scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: false)
            }
        }
    }
}

private final class ReaderScrollCoordinator: NSObject, UIScrollViewDelegate {
    var box: ReaderScrollBox?
    var hosting: UIHostingController<AnyView>?
    var token = -1

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        box?.value = scrollView.contentOffset.y
    }
}

/// 滚动位置暂存：写它不触发 SwiftUI 重绘（阅读时滚动不抖）
final class ReaderScrollBox {
    var value: CGFloat = 0
}

// MARK: - 小工具

/// 字数文案（与安卓 formatWords 对齐）
private func novelFormatWords(_ w: Int) -> String {
    if w >= 10000 {
        return String(format: "%.1f 万字", Double(w) / 10000.0)
    } else if w > 0 {
        return "\(w) 字"
    } else {
        return "字数未知"
    }
}

/// 正文是不是 HTML（安卓直接渲染纯文本，这里带 HTML 时转富文本）
private func looksLikeHtml(_ s: String) -> Bool {
    s.range(
        of: "<\\s*/?\\s*(br|p|div|b|i|u|s|strong|em|del|span|h[1-6]|li|blockquote)",
        options: .regularExpression
    ) != nil
}
