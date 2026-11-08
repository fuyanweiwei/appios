import SwiftUI

// ====== 设置（SettingsScreen.kt 对齐）：外观 / 站点访问 / 账号 ======

struct SettingsScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var baseUrl: String = Prefs.shared.baseUrl
    @State private var apiPassword: String = Prefs.shared.apiPassword
    @State private var confirmLogout = false

    var body: some View {
        OverlayScaffold(title: "设置") {
            VStack(spacing: 16) {
                appearanceCard
                siteCard
                accountCard
            }
            .padding(16)
        }
    }

    // ---- 外观：深色模式 + 主题色（与网站一致的可换肤能力）----

    private var appearanceCard: some View {
        SettingsCard(title: "外观（主题）") {
            Text("深色模式")
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)

            Picker("", selection: Binding(
                get: { vm.themeMode },
                set: { vm.setThemeMode($0) }
            )) {
                Text("跟随系统").tag("system")
                Text("浅色").tag("light")
                Text("深色").tag("dark")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.top, 8)

            Text("主题色")
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .padding(.top, 6)

            HStack(spacing: 12) {
                ForEach(AccentPresets.indices, id: \.self) { index in
                    accentDot(index)
                }
            }

            Text("与网站一致的默认蓝 #4299E1，可切换其他主题色；深色模式可跟随系统。")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func accentDot(_ index: Int) -> some View {
        let preset = AccentPresets[index]
        let selected = vm.accentIndex == index
        return Button {
            vm.setAccentIndex(index)
        } label: {
            Circle()
                .fill(preset.color)
                .frame(width: 30, height: 30)
                .overlay {
                    if selected {
                        Text("✓")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    if selected {
                        Circle().strokeBorder(Color.white, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(preset.name)
    }

    // ---- 站点访问（防火墙密码）----

    private var siteCard: some View {
        SettingsCard(title: "站点访问（防火墙密码）") {
            SettingsField(label: "站点地址", placeholder: "https://frp-box.com:40932", text: $baseUrl)
            SettingsField(label: "防火墙 / 拦截页密码",
                          placeholder: "访问被拦截时自动填入验证页",
                          text: $apiPassword,
                          secure: true)

            Button {
                if baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    vm.showMessage("站点地址不能为空")
                } else {
                    vm.saveApiSettings(url: baseUrl.trimmingCharacters(in: .whitespaces), password: apiPassword)
                }
            } label: {
                Text("保存设置")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.onPrimary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.primary))
            }
            .buttonStyle(.plain)

            Text("保留自动填充：接口返回防火墙/拦截页时，会打开验证页并自动填入上方密码（回车确认），验证通过的 Cookie 会带给后续所有 API 请求。密码仅存本地，不随请求发送。")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // ---- 账号 ----

    private var accountCard: some View {
        SettingsCard(title: "账号") {
            Text("当前登录：\(vm.username.isEmpty ? "未登录" : vm.username)（ID \(vm.userId)）")
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                confirmLogout = true
            } label: {
                Text("退出登录")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(palette.outline)
                    )
            }
            .buttonStyle(.plain)

            Text("登录使用网站账号密码，会话（Session）保存在本地，用于访问全部站点接口。")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("确定退出登录吗？", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("退出登录", role: .destructive) {
                vm.logout()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("退出后需要重新登录")
        }
    }
}

/// 卡片（SettingsCard 等价）
private struct SettingsCard<Content: View>: View {
    let title: String
    @Environment(\.palette) var palette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.onBackground)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(palette.surface)
                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.075), radius: 4, y: 1)
        )
    }
}

/// 带标签的输入框（OutlinedTextField 等价）
private struct SettingsField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var secure: Bool = false
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)
            Group {
                if secure {
                    SecureField(placeholder, text: $text, prompt: Text(placeholder))
                } else {
                    TextField(placeholder, text: $text, prompt: Text(placeholder))
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(palette.onBackground)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))
        }
    }
}
