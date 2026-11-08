import SwiftUI

// ====== 使用统计（UsageStatsScreen.kt 对齐）：只有自己能看的本地数据 ======

struct UsageStatsScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    private var stats: [String: [String: Int]] { UsageTracker.localStats() }
    private var pending: Int { UsageTracker.pendingTotal() }

    var body: some View {
        OverlayScaffold(title: "使用统计") {
            if stats.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 40)
            Text("📊")
                .font(.system(size: 34))
            Text("还没有本地记录")
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
            Text("签到、发日常、看图之后再来看看")
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }

    private var listContent: some View {
        VStack(spacing: 12) {
            // Q-9：本机最近一次冷启动耗时（进程启动 → 首帧可见）
            if vm.prefs.lastColdStartMs > 0 {
                Text("上次冷启动 \(vm.prefs.lastColdStartMs)ms（进程启动 → 首帧可见）")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            // 总计
            totalsCard
                .padding(.top, 4)

            // 上报规则说明
            VStack(alignment: .leading, spacing: 4) {
                Text(pending > 0 ? "待推送 \(pending) 条" : "已全部推送")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.onBackground)
                Text("每次打开 App 检查一次：攒够 20 条或距上次超过 24 小时，就自动上报给网站。")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(palette.surfaceVariant))

            // 按天（日期倒序）
            ForEach(stats.keys.sorted(by: >), id: \.self) { date in
                dayCard(date: date, row: stats[date] ?? [:])
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalsCard: some View {
        let totals = mergedTotals()
        let totalAll = totals.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: 10) {
            Text("累计 \(totalAll) 次 · 覆盖 \(stats.count) 天")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.onBackground)

            ForEach(totals) { item in
                HStack {
                    Text(UsageTracker.LABELS[item.event] ?? item.event)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.onBackground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(item.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
        )
    }

    private func dayCard(date: String, row: [String: Int]) -> some View {
        let events = row
            .sorted { $0.value > $1.value }
            .map { EventCount(event: $0.key, count: $0.value) }
        return VStack(alignment: .leading, spacing: 6) {
            Text(date)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(palette.primary)

            ForEach(events) { item in
                HStack {
                    Text(UsageTracker.LABELS[item.event] ?? item.event)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("× \(item.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.onBackground)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
        )
    }

    /// 累计（按次数倒序）
    private func mergedTotals() -> [EventCount] {
        var map: [String: Int] = [:]
        for (_, row) in stats {
            for (event, count) in row {
                map[event, default: 0] += count
            }
        }
        return map
            .sorted { $0.value > $1.value }
            .map { EventCount(event: $0.key, count: $0.value) }
    }
}

/// 事件 → 次数（列表行）
private struct EventCount: Identifiable {
    let event: String
    let count: Int
    var id: String { event }
}
