import SwiftUI

// ====== 小组件（Common.kt 对齐）======

/// 标签 chip（Tag composable 等价）
struct TagChip: View {
    let text: String
    var accent: Bool = false
    @Environment(\.palette) var palette

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(accent ? palette.primaryContainer : palette.surfaceVariant)
            )
            .foregroundStyle(accent ? palette.onPrimaryContainer : palette.onSurfaceVariant)
    }
}

/// 分段下栏 Tab 的胶囊高亮（QQ 式）
struct PillButtonStyle: ButtonStyle {
    let selected: Bool
    @Environment(\.palette) var palette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: selected ? .bold : .medium))
            .foregroundStyle(selected ? palette.onPrimaryContainer : palette.onSurfaceVariant)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? palette.primaryContainer : Color.clear)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 覆盖层通用顶栏（MallScreens OverlayScaffold 等价）
struct OverlayScaffold<Content: View>: View {
    let title: String
    var trailing: AnyView? = nil
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    vm.popOverlay()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.onBackground)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(palette.surfaceVariant.opacity(0.7)))
                }
                Spacer()
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.onBackground)
                Spacer()
                if let trailing {
                    trailing
                } else {
                    Color.clear.frame(width: 38, height: 38)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.surface)
            Divider().overlay(palette.outlineVariant)
            ScrollView {
                content
                    .frame(maxWidth: .infinity)
            }
            .background(palette.background)
        }
        .background(palette.background)
    }
}

/// 分页加载指示（PagingUi LoadMoreEffect 等价）：滑到底自动触发，带重试
struct LoadMoreEffect: View {
    let hasMore: Bool
    let loading: Bool
    let action: () -> Void
    @State private var retries = 0

    var body: some View {
        Color.clear
            .frame(height: 1)
            .onAppear { trigger() }
            .onChange(of: loading) { _, now in
                if !now { retries = 0 }
            }
            .onChange(of: hasMore) { _, _ in trigger() }
    }

    private func trigger() {
        guard hasMore, !loading else { return }
        if retries >= 6 { return }
        retries += 1
        action()
    }
}
