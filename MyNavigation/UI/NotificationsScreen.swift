import SwiftUI

// ====== 站内通知中心（NotificationsScreen.kt 对齐）======
// 列表 = /api/notification/dynamic/list，点开即已读，支持一键全部已读；
// 顶栏铃铛角标由 AppViewModel.notifUnread 维护。

struct NotificationsScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @MainActor
    private var unread: Int {
        vm.notifList.filter { !$0.optBoolean("isRead") }.count
    }

    var body: some View {
        OverlayScaffold(title: "通知") {
            VStack(spacing: 0) {
                header
                listArea
            }
        }
        .onAppear { vm.loadNotifications() }
    }

    // MARK: - 顶部：共 N 条 + 全部已读

    @MainActor
    private var header: some View {
        HStack(spacing: 8) {
            Text("共 \(vm.notifList.count) 条" + (unread > 0 ? " · 未读 \(unread)" : ""))
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            if unread > 0 {
                Button {
                    vm.markAllNotifRead()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14))
                        Text("全部已读")
                            .font(.system(size: 13))
                    }
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .overlay(Capsule().stroke(palette.outline, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - 骨架 / 空 / 列表三态

    @MainActor
    @ViewBuilder
    private var listArea: some View {
        if vm.notifLoading && vm.notifList.isEmpty {
            SkeletonCards(count: 5)
                .padding(.horizontal, 16)
        } else if vm.notifList.isEmpty {
            VStack(spacing: 10) {
                Text("🔔")
                    .font(.system(size: 44))
                Text("还没有通知")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.onSurfaceVariant)
                Text("有人操作共享功能时会在这里提醒你")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 56)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(vm.notifList.indices, id: \.self) { i in
                    NotificationCard(item: vm.notifList[i]) {
                        vm.markNotifRead(vm.notifList[i].optLong("id"))
                    }
                }

                // A-4：滑到底继续加载
                if vm.notifHasMore {
                    Text(vm.notifLoading ? "加载中…" : "上滑加载更多…")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                LoadMoreEffect(hasMore: vm.notifHasMore, loading: vm.notifLoading) {
                    vm.moreNotifications()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - 单条通知卡片（未读高亮）

private struct NotificationCard: View {
    let item: Json
    let onClick: () -> Void
    @Environment(\.palette) var palette

    private var isRead: Bool { item.optBoolean("isRead") }

    var body: some View {
        Button(action: onClick) {
            HStack(alignment: .top, spacing: 10) {
                if !isRead {
                    Circle()
                        .fill(palette.primary)
                        .frame(width: 8, height: 8)
                        .padding(.top, 7)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.optString("name").isEmpty ? "通知" : item.optString("name"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(palette.onBackground)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !isRead {
                            Image(systemName: "envelope.open")
                                .font(.system(size: 14))
                                .foregroundStyle(palette.primary)
                        }
                    }

                    Text(item.optString("message"))
                        .font(.system(size: 13))
                        .lineSpacing(5)
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(absNotifTime(item.optString("createdAt")))
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isRead ? palette.surface : palette.primaryContainer)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 小工具

/// 安卓：createdAt.replace('T', ' ').take(16)
private func absNotifTime(_ raw: String) -> String {
    String(raw.replacingOccurrences(of: "T", with: " ").prefix(16))
}
