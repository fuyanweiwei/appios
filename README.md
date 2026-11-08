# 薇薇导航 · iOS 端（mynavigationios）

`mynavigationapp`（安卓 Compose）的 iOS 对应实现，功能一一对应，SwiftUI + 纯系统框架、零第三方依赖。

## 构建（需 macOS + Xcode 15+）

```bash
brew install xcodegen      # 若未安装
cd mynavigationios
xcodegen generate          # 生成 MyNavigation.xcodeproj
open MyNavigation.xcodeproj
```

在 Xcode 里为三个 target 选择你的开发团队（Automatic signing）：

| Target | Bundle ID | 说明 |
|---|---|---|
| MyNavigation | com.weiwei.mynavigation | 主 App |
| MyWidget | com.weiwei.mynavigation.widget | 桌面小组件（连签 + 一键签到） |
| ShareExtension | com.weiwei.mynavigation.share | 系统分享 →「存到贴板」 |

三个 target 共用 App Group `group.com.weiwei.mynavigation`（小组件/分享扩展读取登录态与签到状态），需同一开发者账号签名才生效。

## 结构

```
project.yml              XcodeGen 工程定义（Info.plist 属性、ATS、权限、后台任务都在这）
CONVENTIONS.md           移植约定（Android ↔ SwiftUI 对照规则）
MyNavigation/
  App/                   入口、路由根、登录页、防火墙验证页
  Core/                  Json/Models/Prefs(Keychain)/ApiClient(含防火墙静默认证)/
                         Theme/UsageTracker/CrashReporter/NotificationPoll(后台轮询)
  State/                 AppViewModel（核心 + 10 个域扩展，与安卓方法同名）
  UI/                    AppShell(下栏/顶栏/覆盖层宿主) + 各 Tab 与浮层 + Shared 组件
MyWidget/                WidgetKit 小组件 + App Intent 一键签到
ShareExtension/          分享扩展（POST api/board/save）
```

## 与安卓端的能力对照

| 安卓 | iOS |
|---|---|
| OkHttp + TrustAll | URLSession + 信任自签名证书的 delegate（Cookie 经 HTTPCookieStorage 与 WKWebView 共享）|
| EncryptedSharedPreferences | Keychain（token/防火墙密码）+ App Group UserDefaults |
| Compose Material3 主题/强调色 | SwiftUI `palette` 环境值（同色板，深浅色自动） |
| WorkManager 15 分钟通知轮询 | BGAppRefreshTask（earliestBeginDate 15 分钟，系统调度）+ 进入前台即轮询 |
| 桌面小组件 + 广播签到 | WidgetKit + `Button(intent: CheckInIntent())` 一键签到 |
| ACTION_SEND 分享 → 贴板 | Share Extension |
| Coil 三态图片 | SmartImage（探活 + AsyncImage，带失败重试）|
| zxing 二维码 | CoreImage 生成 + AVCaptureSession 扫描 |
| WebView 游戏容器 | WKWebView（JS/DOM、SSL proceed、站内外分流、历史返回） |
| 深链 mynavigation:// | CFBundleURLTypes 同 scheme，通知点击经 onOpenURL 路由 |
| EncryptedSP 迁移兜底逻辑 | Keychain 失败退回 UserDefaults（功能优先，绝不锁死） |

## 已知平台差异

- iOS 后台刷新由系统调度，15 分钟是下限不是保证；App 回前台会立即补一次轮询。
- 小组件进程读 Keychain 可能被拒：签到请求降级为只带 `X-User-Id`。
- iOS 无「跨 App 接收文本」的等价物，接收分享走 Share Extension（主动分享面板）。
- 反馈评分的 module 字段为 `iOS App`（安卓为 `安卓App`），其余接口参数完全一致。

## 本仓库在 Windows 上生成

源码在 Windows 上编写，未经过 Xcode 编译；`xcodegen generate` 后如有个别编译报错，多为拼写级问题，按报错行修正即可。
