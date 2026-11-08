import SwiftUI

// ====== 贴板（对照 Android ui/BoardScreens.kt）======
// BoardTab：公版 / 私记分段 + 笔记卡片流 + 查看弹层 + 「写贴板」FAB
// BoardEditScreen：写贴板 / 修改贴板（HtmlEditor + 私记邮件闹钟）

// MARK: - 贴板 Tab

@MainActor struct BoardTab: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var viewing: Json? = nil

    private var visibleNotes: [Json] { Array(vm.boardNotes.prefix(vm.boardShown)) }
    private var hasMoreBoard: Bool { vm.boardShown < vm.boardNotes.count }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                scopeBar
                boardBody
            }
            fab
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
        .onAppear { vm.loadBoard() }
        .overlay { viewOverlay }
        .animation(.easeInOut(duration: 0.16), value: viewing != nil)
    }

    // 公版 / 私记（安卓 TabRow，indicator/divider 置空）
    private var scopeBar: some View {
        HStack(spacing: 0) {
            scopeTab("public", "公版")
            scopeTab("private", "私记")
        }
        .frame(maxWidth: .infinity)
        .background(palette.surface)
    }

    @MainActor
    private func scopeTab(_ scope: String, _ label: String) -> some View {
        let selected = vm.boardScope == scope
        return Button {
            vm.switchBoardScope(scope)
        } label: {
            Text(label)
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? palette.primary : palette.onSurfaceVariant)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // 骨架 / 失败 / 空 / 列表 四态（Q-1、Q-3）
    @ViewBuilder
    private var boardBody: some View {
        if vm.boardLoading && vm.boardNotes.isEmpty {
            SkeletonCards(count: 5)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if vm.boardNotes.isEmpty && vm.listError != nil {
            ErrorState(message: vm.listError ?? "加载失败") { vm.loadBoard() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.boardNotes.isEmpty {
            // Android 原文 + 空态 emoji 📝
            EmptyState(
                emoji: "📝",
                text: vm.boardScope == "private" ? "私记还是空的，点右下角写一条" : "公版暂时没有内容"
            )
        } else {
            boardList
        }
    }

    @MainActor
    private var boardList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(visibleNotes.indices, id: \.self) { i in
                    let note = visibleNotes[i]
                    BoardNoteCard(note: note) { viewing = note }
                }
                if hasMoreBoard {
                    Text("上滑加载更多…")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                }
                // 本地分批展示（boardShown 每次 +20）；.id 让指示器在翻批后重新触发
                LoadMoreEffect(hasMore: hasMoreBoard, loading: vm.loadingMore) { vm.moreBoard() }
                    .id("board-\(vm.boardShown)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 96)
        }
    }

    @MainActor
    private var fab: some View {
        Button {
            vm.pushOverlay(.boardEdit(noteId: nil, title: "", content: "", scope: vm.boardScope))
        } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.onPrimary)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 18).fill(palette.primary))
                .shadow(color: palette.primary.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写贴板")
        .padding(20)
    }

    // 点卡片 → 查看弹层（可进编辑）
    @MainActor
    @ViewBuilder
    private var viewOverlay: some View {
        if let note = viewing {
            BoardViewDialog(
                note: note,
                canEdit: vm.boardScope == "public" || note.optLong("userId") == vm.userId,
                onClose: { viewing = nil },
                onEdit: {
                    let sc = note.optString("scope", vm.boardScope)
                    viewing = nil
                    vm.pushOverlay(.boardEdit(
                        noteId: note.optLong("id"),
                        title: note.optString("title"),
                        content: note.optString("content"),
                        scope: sc
                    ))
                }
            )
        }
    }
}

// MARK: - 笔记卡片

@MainActor private struct BoardNoteCard: View {
    let note: Json
    let onClick: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        let isPrivate = note.optString("scope") == "private"
        let content = note.optString("content")
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(isPrivate ? "🔒 私记" : "🌐 公版")
                        .font(.system(size: 11))
                        .foregroundStyle(isPrivate ? palette.tertiary : palette.primary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isPrivate ? palette.tertiary.opacity(0.15) : palette.primaryContainer)
                        )
                    Text(note.optString("title", "无标题"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                }
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(htmlToPlain(content, max: 160))
                        .font(.system(size: 13))
                        .foregroundStyle(palette.onBackground.opacity(0.85))
                        .lineLimit(4)
                        .padding(.top, 6)
                }
                HStack {
                    Text(note.optString("creatorName").isEmpty ? "我" : note.optString("creatorName"))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                    Spacer()
                    Text(boardTimeText(note))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                .padding(.top, 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(palette.isDark ? 0.28 : 0.06), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 查看详情弹层（点「编辑」进写贴板）

@MainActor private struct BoardViewDialog: View {
    let note: Json
    let canEdit: Bool
    let onClose: () -> Void
    let onEdit: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(note.optString("title", "无标题"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: 4)
                    if canEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 17))
                                .foregroundStyle(palette.primary)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(note.optString("creatorName") + " · " + boardTimeText(note))
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView(showsIndicators: false) {
                    HtmlText(
                        html: note.optString("content").isEmpty ? "（无内容）" : note.optString("content"),
                        font: .system(size: 14),
                        color: palette.onBackground
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                }
                .frame(maxHeight: 520)

                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Text("关闭")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.onPrimary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(palette.primary))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
            }
            .padding(20)
            .frame(maxWidth: 640)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
    }
}

// MARK: - 写贴板 / 修改贴板

@MainActor struct BoardEditScreen: View {
    let noteId: Int?
    let title: String
    let content: String
    let scope: String

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var titleText: String
    @State private var contentHtml: String
    // P1-7：只有用户动过闹钟才随保存下发（否则保留服务端已有设置）
    @State private var alarmTouched = false
    @State private var alarmOn = false
    @State private var alarmDate = defaultAlarmDate()
    @State private var alarmPeriod = "once"

    init(noteId: Int?, title: String, content: String, scope: String) {
        self.noteId = noteId
        self.title = title
        self.content = content
        self.scope = scope
        _titleText = State(initialValue: title)
        _contentHtml = State(initialValue: content)
    }

    private var isEdit: Bool { noteId != nil }
    private var isPrivate: Bool { scope == "private" }

    var body: some View {
        OverlayScaffold(title: "写贴板") {
            editorContent
        }
    }

    @MainActor
    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isEdit ? "修改贴板" : "写贴板（\(isPrivate ? "私记" : "公版")）")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(palette.onBackground)

            // 标题
            TextField("标题", text: $titleText)
                .font(.system(size: 15))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(palette.outline)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // 正文（工具条 B/I/U/S/↵ 由共享 HtmlEditor 提供）
            HtmlEditor(
                html: contentHtml,
                onHtmlChange: { contentHtml = $0 },
                placeholder: "写点内容，工具条支持加粗/斜体/下划线…"
            )
            .frame(height: 300)

            // ====== P1-7 邮件闹钟（仅私记）======
            if isPrivate {
                alarmCard
            }

            Button(action: save) {
                Text(isEdit ? "保存修改" : "发布")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.primary))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    @ViewBuilder
    private var alarmCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("⏰ 闹钟提醒")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                Spacer()
                Toggle("", isOn: $alarmOn)
                    .labelsHidden()
                    .tint(palette.primary)
                    .onChange(of: alarmOn) { _, _ in alarmTouched = true }
            }
            Text("到点由服务端发站内通知 + 邮件（App 需已允许通知）")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)

            if alarmOn {
                DatePicker(
                    "时间（2026-11-05 21:00）",
                    selection: $alarmDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(.system(size: 13))
                .onChange(of: alarmDate) { _, _ in alarmTouched = true }

                Text("重复")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .padding(.top, 2)

                HStack(spacing: 6) {
                    ForEach(ALARM_PERIODS.indices, id: \.self) { i in
                        let key = ALARM_PERIODS[i].0
                        let label = ALARM_PERIODS[i].1
                        let active = alarmPeriod == key
                        Button {
                            alarmPeriod = key
                            alarmTouched = true
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: active ? .bold : .regular))
                                .foregroundStyle(active ? palette.primary : palette.onSurfaceVariant)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(active ? palette.primary : palette.outline)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if isEdit {
                Text("未改动则保持原有闹钟不变")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @MainActor
    private func save() {
        let iso = alarmISO(alarmDate)
        if isPrivate && alarmTouched && alarmOn && iso.isEmpty {
            vm.showMessage("闹钟时间格式不对，请写成 2026-11-05 21:00")
            return
        }
        let alarm: BoardAlarmPayload? = (isPrivate && alarmTouched)
            ? BoardAlarmPayload(enabled: alarmOn, atIso: iso, period: alarmPeriod)
            : nil
        vm.saveBoardNote(id: noteId, title: titleText, content: contentHtml, scope: scope, alarm: alarm)
    }
}

// MARK: - 小工具

private let ALARM_PERIODS: [(String, String)] = [
    ("once", "仅一次"),
    ("daily", "每天"),
    ("weekly", "每周"),
    ("monthly", "每月"),
]

/// 卡片时间：updatedAt（T 换空格，取前 16 位），没有就用 createdAt
private func boardTimeText(_ note: Json) -> String {
    let updated = note.optString("updatedAt")
        .replacingOccurrences(of: "T", with: " ")
    let t = String(updated.prefix(16))
    if !t.isEmpty { return t }
    let created = note.optString("createdAt")
        .replacingOccurrences(of: "T", with: " ")
    return String(created.prefix(16))
}

/// P1-7 默认闹钟时间：一小时后
private func defaultAlarmDate() -> Date {
    Date().addingTimeInterval(3600)
}

/// DatePicker → 后端要的 ISO：yyyy-MM-ddTHH:mm（LocalDateTime.parse 认这个格式）
private func alarmISO(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mm"
    return f.string(from: date)
}
