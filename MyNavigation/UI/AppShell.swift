import SwiftUI
import UIKit

// ====== 主壳：QQ 式下栏 + 品牌顶栏 + 覆盖层宿主（AppShell.kt 对齐）======

struct MainShell: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var showDrawer = false

    private var wide: Bool { UIScreen.main.bounds.width >= 600 }

    var body: some View {
        // 覆盖层优先：有浮层时全屏显示最上层
        if let current = vm.overlays.last {
            OverlayHost(overlay: current)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            baseShell
        }
    }

    private var baseShell: some View {
        VStack(spacing: 0) {
            BrandTopBar()
            if !vm.online {
                // B0-11：断网横幅（恢复联网后 ViewModel 自动补刷新）
                Text("📡 网络不可用，正在展示缓存内容")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onErrorContainer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(palette.errorContainer)
            }
            ZStack {
                tabContent
                    // 下拉刷新（实用页本地计算，无网络加载态）
                    .refreshable {
                        switch vm.tab {
                        case .home: vm.refreshHome()
                        case .board: vm.loadBoard()
                        case .media: vm.refreshMedia()
                        case .features: vm.refreshFeatures()
                        case .tools: break
                        }
                    }

                // 右下角笔按钮：随页面/分栏切换（贴板自带 FAB，此处不放）
                if let target = fabTarget {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: target) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(palette.onPrimary)
                                    .frame(width: 56, height: 56)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(palette.primary))
                                    .shadow(color: palette.primary.opacity(0.35), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 18)
                            .padding(.bottom, 18)
                        }
                    }
                }
            }
            if !wide {
                AppBottomBar()
            }
        }
        .background(palette.background)
        .overlay(alignment: .trailing) {
            // 宽屏左侧导航栏
            if wide {
                AppRail()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openProfileDrawer)) { _ in
            showDrawer = true
        }
        .sheet(isPresented: $showDrawer) {
            ProfileDrawer(onClose: { showDrawer = false })
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
        }
    }

    /// FAB 目标（随首页分栏切换；动态无 FAB；贴板自带）
    private var fabTarget: (() -> Void)? {
        switch vm.tab {
        case .home:
            switch vm.homeFeed {
            case .daily: return { vm.pushOverlay(.composeDaily) }
            case .column: return { vm.pushOverlay(.composeColumn(id: nil, title: "", content: "", type: "其他")) }
            case .dynamic: return nil
            }
        default:
            return nil
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.tab {
        case .home: HomeTab()
        case .board: BoardTab()
        case .media: MediaTab()
        case .features: FeaturesTab()
        case .tools: ToolsTab()
        }
    }
}

// ====== 顶栏：左上角头像（开抽屉）+ 任务（仅首页）+ 通知铃铛（角标）======

private struct BrandTopBar: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        HStack(spacing: 8) {
            Button {
                // 抽屉由 MainShell 的 sheet 承载：这里通过通知打开
                NotificationCenter.default.post(name: .openProfileDrawer, object: nil)
            } label: {
                Text(String(vm.username.first ?? "薇"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.onPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(palette.primary))
            }
            .buttonStyle(.plain)

            Spacer()

            if vm.tab == .home {
                Button {
                    vm.pushOverlay(.tasks)
                } label: {
                    Image(systemName: "checklist")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.primary)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }

            Button {
                vm.pushOverlay(.notifications)
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(width: 40, height: 40)
                    if vm.notifUnread > 0 {
                        Text(vm.notifUnread > 99 ? "99+" : "\(vm.notifUnread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 8, y: 4)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.surface)
    }
}

extension Notification.Name {
    static let openProfileDrawer = Notification.Name("openProfileDrawer")
}

// ====== QQ 式下栏 ======

private struct AppBottomBar: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                let selected = tab == vm.tab
                Button {
                    vm.selectTab(tab)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: icon(for: tab))
                            .font(.system(size: 19))
                            .foregroundStyle(selected ? palette.primary : palette.onSurfaceVariant)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selected ? palette.primaryContainer : Color.clear)
                            )
                        Text(tab.label)
                            .font(.system(size: 11, weight: selected ? .bold : .medium))
                            .foregroundStyle(selected ? palette.primary : palette.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 66)
        .padding(.horizontal, 8)
        .background(palette.surface.shadow(.drop(color: .black.opacity(0.08), radius: 8, y: 2)))
    }

    private func icon(for tab: MainTab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .board: return "note.text"
        case .media: return "photo.on.rectangle.angled"
        case .features: return "star.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        }
    }
}

// ====== 宽屏左侧导航栏（≥600pt）======

private struct AppRail: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        VStack(spacing: 8) {
            ForEach(MainTab.allCases) { tab in
                let selected = tab == vm.tab
                Button {
                    vm.selectTab(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: tab))
                            .font(.system(size: 20))
                        Text(tab.label)
                            .font(.system(size: 11, weight: selected ? .bold : .medium))
                    }
                    .foregroundStyle(selected ? palette.primary : palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selected ? palette.primaryContainer : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(width: 92)
        .frame(maxHeight: .infinity)
        .background(palette.surface.shadow(.drop(color: .black.opacity(0.06), radius: 6, x: -2)))
    }

    private func icon(for tab: MainTab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .board: return "note.text"
        case .media: return "photo.on.rectangle.angled"
        case .features: return "star.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        }
    }
}

// ====== 覆盖层宿主（24 个浮层 + 右滑 1/4 + 淡入动画）======

private struct OverlayHost: View {
    let overlay: Overlay
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        content
            .background(palette.background)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeOut(duration: 0.18), value: vm.overlays.count)
            .onAppear {
                DiagTrace.step("overlay → \(label(of: overlay))")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch overlay {
        case .settings: SettingsScreen()
        case .profile: ProfileScreen()
        case .notifications: NotificationsScreen()
        case .feedback: FeedbackScreen()
        case .gift: GiftScreen()
        case .backpack: BackpackScreen()
        case .achievement: AchievementScreen()
        case let .featureList(appType, title): FeatureListScreen(appType: appType, title: title)
        case .novelDetail: NovelDetailScreen()
        case .novelReader: NovelReaderScreen()
        case .composeDaily: ComposeDailyScreen()
        case let .mediaViewer(items, index): MediaViewerScreen(items: items, index: index)
        case .tasks: TaskScreen()
        case .board: BoardTab()
        case let .boardEdit(noteId, title, content, scope):
            BoardEditScreen(noteId: noteId, title: title, content: content, scope: scope)
        case let .composeColumn(id, title, content, type):
            ComposeColumnScreen(id: id, title: title, content: content, type: type)
        case let .featureDetail(appType, row): FeatureDetailScreen(appType: appType, row: row)
        case let .featureEdit(appType, title, row): FeatureEditScreen(appType: appType, title: title, row: row)
        case .leaderboard: LeaderboardScreen()
        case .gameCenter: GameCenterScreen()
        case let .gameContainer(url, title): GameContainerScreen(url: url, title: title)
        case let .toolDetail(id, title): ToolDetailScreen(toolId: id, title: title)
        case let .columnDetail(col): ColumnDetailScreen(col: col)
        case let .giftEdit(gift): GiftEditScreen(gift: gift)
        case .usageStats: UsageStatsScreen()
        }
    }

    private func label(of o: Overlay) -> String {
        switch o {
        case .settings: return "Settings"
        case .profile: return "Profile"
        case .notifications: return "Notifications"
        case .feedback: return "Feedback"
        case .gift: return "Gift"
        case .backpack: return "Backpack"
        case .achievement: return "Achievement"
        case .featureList(let a, _): return "FeatureList(\(a))"
        case .novelDetail: return "NovelDetail"
        case .novelReader: return "NovelReader"
        case .composeDaily: return "ComposeDaily"
        case .mediaViewer: return "MediaViewer"
        case .tasks: return "Tasks"
        case .board: return "Board"
        case .boardEdit: return "BoardEdit"
        case .composeColumn: return "ComposeColumn"
        case .featureDetail(let a, _): return "FeatureDetail(\(a))"
        case .featureEdit(let a, _, _): return "FeatureEdit(\(a))"
        case .leaderboard: return "Leaderboard"
        case .gameCenter: return "GameCenter"
        case .gameContainer: return "GameContainer"
        case .toolDetail(let id, _): return "ToolDetail(\(id))"
        case .columnDetail: return "ColumnDetail"
        case .giftEdit: return "GiftEdit"
        case .usageStats: return "UsageStats"
        }
    }
}

func featureDefOf(_ appType: String) -> FeatureDef {
    FEATURE_CATALOG.first { $0.appType == appType }
        ?? FeatureDef(appType, appType, "📄", [])
}
