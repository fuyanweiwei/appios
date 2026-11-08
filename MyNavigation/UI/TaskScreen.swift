import SwiftUI

// ====== 任务版：今日任务完成情况（TaskScreen.kt 对齐）======

struct TaskScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    var body: some View {
        OverlayScaffold(title: "任务版 · 今日") {
            VStack(alignment: .leading, spacing: 12) {
                if let t = vm.tasks {
                    coinCard(t)

                    TaskRow(
                        title: "每日签到",
                        subtitle: vm.checkedIn ? "已签到，连签奖励已发放" : "点首页签到条完成",
                        done: vm.checkedIn
                    )
                    TaskRow(
                        title: "发布记录",
                        subtitle: "今日新增 \(t.recordCount) 条 · +\(t.recordCoins) 金币",
                        done: t.recordCount > 0
                    )
                    TaskRow(
                        title: "记录心情（#心情）",
                        subtitle: t.moodDone ? "今天已记录心情" : "发一条带 #心情 标签的日常",
                        done: t.moodDone
                    )
                    TaskRow(
                        title: "签到奖励明细",
                        subtitle: "签到入账 +\(t.checkInCoins) · 发记录 +\(t.recordCoins)",
                        done: true
                    )

                    Text("规则与网站任务版一致：每条新记录 +1 金币，签到按连签天数发金币，3 天以上额外随机 bonus。")
                        .font(.system(size: 12))
                        .lineSpacing(6)
                        .foregroundStyle(palette.onSurfaceVariant)
                        .padding(.top, 4)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(palette.primary)
                        Text("加载中…")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.onSurfaceVariant)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            vm.loadTasks()
            vm.refreshHome()
        }
    }

    // MARK: - 今日金币卡片

    private func coinCard(_ t: TaskToday) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("今日金币")
                .font(.system(size: 13))
                .foregroundStyle(palette.onPrimaryContainer)
            Text("+\(t.totalCoins)")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(palette.primary)
            Text("账户余额 \(t.coins) 金币")
                .font(.system(size: 12))
                .foregroundStyle(palette.onPrimaryContainer.opacity(0.8))
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(palette.primaryContainer))
    }
}

// MARK: - 单条任务行

private struct TaskRow: View {
    let title: String
    let subtitle: String
    let done: Bool
    @Environment(\.palette) var palette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(done ? palette.primary : palette.onSurfaceVariant.opacity(0.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onBackground)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if done {
                Text("✓")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.primary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
    }
}
