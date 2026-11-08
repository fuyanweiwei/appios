import SwiftUI

// ====== 登录（LoginScreen.kt 对齐）======

struct LoginScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var username = ""
    @State private var password = ""
    /// 登录态下也能进设置：push 到覆盖层栈，本页负责把它画出来
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    // 右上设置入口
                    HStack {
                        Spacer()
                        Button {
                            vm.pushOverlay(.settings)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 20))
                                .foregroundStyle(palette.onSurfaceVariant)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("设置")
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 4) {
                        Text("薇薇导航")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(palette.primary)
                        Text("登录网站账号后即可使用全部接口")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.onSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }

                    Spacer(minLength: 28)

                    LoginField(label: "用户名", text: $username, enabled: !vm.loginBusy)
                        .padding(.bottom, 12)
                    LoginField(label: "密码", text: $password, enabled: !vm.loginBusy, secure: true)
                        .padding(.bottom, 20)

                    Button {
                        vm.login(username: username, password: password)
                    } label: {
                        HStack(spacing: 8) {
                            if vm.loginBusy {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(palette.onPrimary)
                                    .scaleEffect(0.8)
                            } else {
                                Text("登 录")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                        }
                        .foregroundStyle(palette.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.loginBusy)
                    .padding(.bottom, 12)

                    Text(vm.message ?? "登录一次即可保持；要换账号请到设置里退出")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 4)

                    Button {
                        vm.pushOverlay(.settings)
                    } label: {
                        Text("先去设置配置站点地址与防火墙密码 →")
                            .font(.system(size: 12))
                            .foregroundStyle(palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
        }
        .background(palette.background)
        // 覆盖层栈里有设置时，本页把它当全屏浮层画出来（登录态下没有 MainShell）
        .overlay {
            if showSettings {
                SettingsScreen()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(palette.background.ignoresSafeArea())
            }
        }
        .onChange(of: vm.overlays) { _, overlays in
            showSettings = overlays.contains(.settings)
        }
    }
}

/// 登录输入框（OutlinedTextField 等价）
private struct LoginField: View {
    let label: String
    @Binding var text: String
    var enabled: Bool = true
    var secure: Bool = false
    @Environment(\.palette) var palette

    var body: some View {
        Group {
            if secure {
                SecureField(label, text: $text, prompt: Text(label))
            } else {
                TextField(label, text: $text, prompt: Text(label))
            }
        }
        .font(.system(size: 15))
        .foregroundStyle(palette.onBackground)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.6)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 10).fill(palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(palette.outline))
    }
}
