import SwiftUI

// ====== 个人中心（ProfileTab.kt 对齐）：左抽屉 + 全屏两种形态 ======

/// 需求7：左抽屉形态的个人中心（顶栏头像点开），内容与 ProfileScreen 一致
struct ProfileDrawer: View {
    let onClose: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("个人中心")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("收起")
            }
            .padding(.leading, 20)
            .padding(.trailing, 6)
            .padding(.top, 18)
            .padding(.bottom, 4)

            ScrollView {
                ProfileContent(onClose: onClose)
                    .padding(.top, 8)
                    // 312dp 宽感
                    .frame(maxWidth: 312, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(palette.background)
    }
}

/// 全屏个人中心
struct ProfileScreen: View {
    var body: some View {
        OverlayScaffold(title: "个人中心") {
            ProfileContent()
        }
    }
}

// ====== 共用内容：账号卡 + P3 入口 + 反馈/统计/设置/网页版/退出 ======

struct ProfileContent: View {
    var onClose: () -> Void = {}

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @Environment(\.openURL) var openURL

    private var stats: Json? { vm.profileStats }

    var body: some View {
        VStack(spacing: 12) {
            accountCard

            // P3 功能入口
            menuCard {
                ProfileMenuRow(icon: "bag.fill", title: "商城", subtitle: "金币兑换好物") {
                    vm.pushOverlay(.gift)
                    onClose()
                }
                ProfileMenuRow(icon: "archivebox.fill", title: "背包", subtitle: "查看拥有的物品") {
                    vm.pushOverlay(.backpack)
                    onClose()
                }
                ProfileMenuRow(icon: "trophy.fill", title: "成就", subtitle: "解锁的荣誉墙") {
                    vm.pushOverlay(.achievement)
                    onClose()
                }
            }

            menuCard {
                ProfileMenuRow(icon: "bubble.left.fill", title: "反馈", subtitle: "提建议 / 报问题 / 评分") {
                    vm.pushOverlay(.feedback)
                    onClose()
                }
                ProfileMenuRow(icon: "chart.bar.fill", title: "使用统计", subtitle: "本地记录：签到 / 发日常 / 看图…") {
                    vm.pushOverlay(.usageStats)
                    onClose()
                }
                ProfileMenuRow(icon: "gearshape.fill", title: "设置", subtitle: "站点地址 · 防火墙密码") {
                    vm.openSettings()
                    onClose()
                }
                // N-5：固定「用浏览器打开网页版」
                ProfileMenuRow(icon: "arrow.up.right.square", title: "网页版", subtitle: "用浏览器打开，功能更全") {
                    onClose()
                    if let u = URL(string: vm.baseUrl) { openURL(u) }
                }
                ProfileMenuRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", subtitle: "下次需要重新登录", danger: true) {
                    vm.logout()
                }
            }

            Text("薇薇导航 · iOS")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .padding(16)
        .onAppear { vm.loadProfileStats() }
    }

    private var accountCard: some View {
        HStack(spacing: 14) {
            Text(String(vm.username.first ?? "薇"))
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.onPrimary)
                .frame(width: 56, height: 56)
                .background(Circle().fill(palette.primary))

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.username.isEmpty ? "未登录" : vm.username)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Lv.\(stats?.optInt("level", 1) ?? 1) · \(stats?.optInt("coins", 0) ?? 0) 金币 · 连签 \(vm.streakCached) 天")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(palette.surface)
                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
        )
    }

    private func menuCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(palette.surface)
                    .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
            )
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var danger: Bool = false
    let onClick: () -> Void

    @Environment(\.palette) var palette

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(danger ? palette.onErrorContainer : palette.primary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(danger ? palette.onErrorContainer : palette.onBackground)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("›")
                    .font(.system(size: 20))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
