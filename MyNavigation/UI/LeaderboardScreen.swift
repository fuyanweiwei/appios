import SwiftUI

// ====== P2-3 各类排行（只读卡片流）：全站金币 / 消费 / 签到（LeaderboardScreen.kt 对齐）======
// 数据 GET `/api/leaderboard/month` → {month, earn[], spend[], checkin[]}

struct LeaderboardScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    private struct Section: Identifiable {
        let label: String
        let key: String
        var id: String { key }
    }

    private let sections: [Section] = [
        Section(label: "金币获得", key: "earn"),
        Section(label: "金币消费", key: "spend"),
        Section(label: "连续签到", key: "checkin"),
    ]

    var body: some View {
        OverlayScaffold(title: "排行榜") {
            content
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .onAppear { vm.loadLeaderboard() }
    }

    @ViewBuilder
    private var content: some View {
        if vm.leaderboardLoading && vm.leaderboard == nil {
            // 骨架屏（替代单个转圈）
            SkeletonCards(count: 3)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .top)
        } else if vm.leaderboard == nil {
            VStack(spacing: 14) {
                Text("榜单还没生成，等服务器结算后再来看")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button {
                    vm.loadLeaderboard()
                } label: {
                    Text("重试")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(palette.primary))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
            .padding(.horizontal, 16)
        } else {
            let data: Json = vm.leaderboard ?? [:]
            let month = data.optString("month")
            LazyVStack(spacing: 12) {
                Text(month.isEmpty ? "全站榜单" : "\(month) 月榜")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)

                ForEach(sections) { section in
                    LeaderboardCard(
                        title: section.label,
                        rows: data.optJSONArray(section.key)?.objects() ?? []
                    )
                }
            }
        }
    }
}

private struct LeaderboardCard: View {
    let title: String
    let rows: [Json]
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.onBackground)

            if rows.isEmpty {
                Text("暂无数据")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }

            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                let rank = row.optInt("rank", index + 1)
                let name = row.optString("nickname").isEmpty
                    ? "用户" + String(row.optLong("userId", 0))
                    : row.optString("nickname")

                HStack(spacing: 10) {
                    Text(medal(rank))
                        .font(.system(size: rank <= 3 ? 15 : 13))
                        .foregroundStyle(rank <= 3 ? palette.onBackground : palette.onSurfaceVariant)
                        .frame(width: 30)

                    Text(String(name.first ?? "用"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(palette.primary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(palette.primaryContainer))

                    Text(name)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(valueText(row))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.primary)
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

    private func medal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }

    private func valueText(_ row: Json) -> String {
        guard let v = row["value"], !(v is NSNull) else { return "-" }
        if let s = v as? String { return s.isEmpty ? "-" : s }
        if let n = v as? NSNumber {
            if String(cString: n.objCType) == "c" { return n.boolValue ? "true" : "false" }
            return n.stringValue
        }
        return String(describing: v)
    }
}
