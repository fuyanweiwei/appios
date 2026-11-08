# iOS 移植约定（mynavigationios）

对照 Android 源码移植到 SwiftUI（iOS 17+）。**先读本文件，再读指定的 Android 源文件，再动手写。**

## 工程结构

```
MyNavigation/
  App/MyNavigationApp.swift   # @main + RootView + ToastView
  Core/                       # Models/Json/Prefs/ApiClient/Theme/UsageTracker...
  State/AppViewModel*.swift   # 核心 + 10 个域扩展（已完成，直接用）
  UI/AppShell.swift           # MainShell + 下栏 + OverlayHost（已完成）
  UI/Shared/                  # SmartImage/Skeleton/Common(HtmlText)/...
  UI/<你的文件>.swift
MyWidget/                     # WidgetKit
ShareExtension/               # 分享扩展
project.yml                   # XcodeGen：`xcodegen generate` 生成工程
```

## 核心 API（已实现，不要重写）

- `@EnvironmentObject var vm: AppViewModel` —— 所有状态与方法都在这里（对照 Android `viewModel.xxx()` 调用，方法名完全一致）。
- `@Environment(\.palette) var palette` —— 语义色：`primary / onPrimary / primaryContainer / onPrimaryContainer / background / surface / onBackground / surfaceVariant / onSurfaceVariant / outline / outlineVariant / secondaryContainer / onSecondaryContainer / tertiary / errorContainer / onErrorContainer / isDark`。**不要直接写死颜色**（暗色模式要正确）。
- `vm.pushOverlay(.xxx)` / `vm.popOverlay()` —— 覆盖层栈。
- 消息提示：`vm.message = "..."`（自动 Toast 2.5s）或 `vm.showMessage("...")`。
- 图片：`SmartImage(url: resolveImg(path))`（`resolveImg` 是 @MainActor）。
- 分页：列表底部放 `LoadMoreEffect(hasMore:loading:action:)`。
- 骨架：`SkeletonCards()`；失败：`ErrorState(message:retry:)`；空态：`EmptyState(emoji:text:)`。
- HTML：`HtmlText(html:)` 渲染，`HtmlEditor(html:onHtmlChange:)` 编辑，`htmlToPlain/_htmlToEditText/editTextToHtml` 工具。
- 分段控件：自绘（TabView .pickerStyle(.segmented) 或自定义胶囊），参考 Android 的 TabRow。
- JSON：服务端数据是 `Json = [String: Any]`，用 `optString/optInt/optLong/optBoolean/optJSONObject/optJSONArray`（已实现，Kotlin 同名）。

## 约定

1. **逐功能对照移植**：读 Android 源文件，把每个 UI 分支、文案、空态、错误态、分页参数都搬过来；文案保持中文原文。
2. 分页参数：列表 `page/size`（20），商城/背包/成就 `page/pageSize`（20），通知新旧后端兼容逻辑在 ViewModel 里已实现。
3. 触摸目标 ≥44pt；用 `@Environment(\.dismiss)` 不要用（覆盖层由 vm 管）。
4. 状态从 vm 读；本地 UI 状态（输入框、展开）用 `@State`。
5. 加载/失败/空三态齐全（对照 Android）。
6. iOS 特有：图片选择用 `PhotosPicker`（iOS16+，`import PhotosUI`），相机用 `UIImagePickerController` 包装，二维码生成用 `CIFilter.qrCodeGenerator`，扫描用 `AVCaptureSession` 或 `DataScannerViewController`，剪贴板 `UIPasteboard.general.string`，本机 IP 用 `getifaddrs`，WebView 用 `WKWebView`（需信任自签名证书：`webView(_:didReceive:completionHandler:)` 里 `challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust` 时 `.useCredential(URLCredential(trust:))`）。
7. 游戏 WebView：JS/DOM 开启、`decidePolicyFor` 区分站内（继续）/站外（开 Safari）、返回键优先网页历史。
8. 每个文件顶部加 `import SwiftUI`（及所需 framework）。文件用 UTF-8。
9. 不要修改 `Core/`、`State/`、`App/`、`AppShell.swift`、`Shared/` 下已有文件（除非任务明确要求补方法——那就最小改动）。
10. 不要引入第三方依赖（纯系统框架）。

## 视图签名（OverlayHost 已按这些名字调用，必须完全一致）

```swift
LoginScreen()                          // 无参
MainShell()                            // 已存在
HomeTab() / BoardTab() / MediaTab() / FeaturesTab() / ToolsTab()   // 无参，内部用 vm
ProfileDrawer(onClose: () -> Void)
SettingsScreen() / ProfileScreen() / NotificationsScreen() / FeedbackScreen()
GiftScreen() / BackpackScreen() / AchievementScreen()
FeatureListScreen(appType: String, title: String)
NovelDetailScreen() / NovelReaderScreen() / ComposeDailyScreen()
MediaViewerScreen(items: [MediaItem], index: Int)
TaskScreen()
BoardEditScreen(noteId: Int?, title: String, content: String, scope: String)
ComposeColumnScreen(id: Int?, title: String, content: String, type: String)
FeatureDetailScreen(appType: String, row: Json)
FeatureEditScreen(appType: String, title: String, row: Json?)
LeaderboardScreen() / GameCenterScreen()
GameContainerScreen(url: String, title: String)
ToolDetailScreen(toolId: String, title: String)
ColumnDetailScreen(col: Json)
GiftEditScreen(gift: Json?)
UsageStatsScreen()
AuthWebViewDialog(url: String, password: String, onRetry: () -> Void, onClose: () -> Void, onSuccess: () -> Void)
```

无参视图全部用 `@EnvironmentObject var vm: AppViewModel` 取状态。

## 已有的共享组件签名

```swift
struct SmartImage { var url: String; var contentMode: ContentMode = .fill }
struct SkeletonBox { var cornerRadius: CGFloat = 10 }
struct SkeletonCards { var count: Int = 3 }
struct ErrorState { let message: String; var retry: (() -> Void)? }
struct EmptyState { let emoji: String; let text: String }
struct TagChip { let text: String; var accent: Bool = false }
struct OverlayScaffold<Content: View> { let title: String; var trailing: AnyView?; @ViewBuilder let content: Content }
struct LoadMoreEffect { let hasMore: Bool; let loading: Bool; let action: () -> Void }
struct HtmlText { let html: String; var font: Font = .system(size: 15); var color: Color = .primary }
struct HtmlEditor { let html: String; let onHtmlChange: (String) -> Void; var placeholder: String = "..." }
struct ToastView { let text: String }   // 已在 RootView 自动挂载
```

`OverlayScaffold` 内部自带返回按钮（vm.popOverlay）。
