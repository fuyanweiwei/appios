import SwiftUI
import Darwin
import UIKit
import AVFoundation
import CoreImage

// ====== 「实用」Tab（ToolsTab.kt 对齐）：工具 / 定制 两个副栏 ======

struct ToolsTab: View {
    @Environment(\.palette) var palette

    @State private var section = 0
    private let sectionNames = ["工具", "定制"]

    var body: some View {
        VStack(spacing: 0) {
            sectionBar
            if section == 0 {
                ToolsEntryGrid()
            } else {
                CustomToolsGrid()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    /// 副上栏：工具 / 定制（TabRow 等价）
    private var sectionBar: some View {
        HStack(spacing: 0) {
            ForEach(sectionNames.indices, id: \.self) { idx in
                Button {
                    section = idx
                } label: {
                    Text(sectionNames[idx])
                        .font(.system(size: 14, weight: section == idx ? .bold : .medium))
                        .foregroundStyle(section == idx ? palette.primary : palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(section == idx ? palette.primary : palette.outlineVariant)
                                .frame(height: 2)
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(palette.surface)
    }
}

// ====== 工具九宫格入口 ======

private struct ToolEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
}

private let TOOL_ENTRIES: [ToolEntry] = [
    ToolEntry(id: "clipboard", name: "剪贴板", emoji: "📋"),
    ToolEntry(id: "timestamp", name: "时间戳", emoji: "🕐"),
    ToolEntry(id: "qrcode", name: "二维码", emoji: "🔳"),
    ToolEntry(id: "random", name: "随机数", emoji: "🎲"),
    ToolEntry(id: "urlcodec", name: "URL 编解码", emoji: "🔗"),
    ToolEntry(id: "ip", name: "IP 查询", emoji: "🌐"),
    ToolEntry(id: "links", name: "常用链接", emoji: "⭐"),
]

/// 需求6：工具改成方块入口（与「功能」九宫格同款），点开进单个工具页
private struct ToolsEntryGrid: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TOOL_ENTRIES) { tool in
                    Button {
                        vm.pushOverlay(.toolDetail(id: tool.id, title: tool.name))
                    } label: {
                        VStack(spacing: 8) {
                            Text(tool.emoji)
                                .font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(palette.primaryContainer)
                                )
                            Text(tool.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(palette.onBackground)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(palette.surface)
                                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}

// ====== 「定制」子栏：站内小工具方块（走 GameContainer 式 WebView）======

private struct CustomTool: Identifiable, Equatable {
    let name: String
    let emoji: String
    let desc: String
    let file: String
    var id: String { file }
}

private let CUSTOM_TOOLS: [CustomTool] = [
    CustomTool(name: "翻译", emoji: "🌐", desc: "多语言互译，随手查", file: "translate"),
    CustomTool(name: "查询热榜", emoji: "🔥", desc: "各平台热榜一览", file: "hotboard"),
]

private struct CustomToolsGrid: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CUSTOM_TOOLS) { tool in
                    Button {
                        let base = trimSlash(vm.baseUrl)
                        vm.pushOverlay(.gameContainer(url: "\(base)/static/skill/\(tool.file).html", title: tool.name))
                    } label: {
                        VStack(spacing: 10) {
                            Text(tool.emoji)
                                .font(.system(size: 22))
                                .frame(width: 46, height: 46)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(palette.primaryContainer)
                                )
                            Text(tool.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.onBackground)
                                .lineLimit(1)
                            Text(tool.desc)
                                .font(.system(size: 11))
                                .foregroundStyle(palette.onSurfaceVariant)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(palette.surface)
                                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
    }
}

// ====== 单个工具页（Overlay.ToolDetail）======

struct ToolDetailScreen: View {
    let toolId: String
    let title: String

    @Environment(\.palette) var palette

    var body: some View {
        OverlayScaffold(title: title) {
            VStack(spacing: 12) {
                switch toolId {
                case "clipboard": ClipboardToolCard()
                case "timestamp": TimestampCard()
                case "qrcode": QrCodeCard()
                case "random": RandomCard()
                case "urlcodec": UrlCodecCard()
                case "ip": IpCard()
                case "links": QuickLinksCard()
                default:
                    Text("工具不存在")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
            }
            .padding(16)
        }
    }
}

// ====== 通用工具卡片 ======

private struct ToolCard<Content: View>: View {
    let title: String
    let hint: String
    let icon: String
    @Environment(\.palette) var palette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.primary)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                    Text(hint)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                Spacer(minLength: 0)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(palette.surface)
                .shadow(color: .black.opacity(palette.isDark ? 0.25 : 0.06), radius: 3, y: 1)
        )
    }
}

private struct ToolButton: View {
    enum Kind { case filled, outlined, text }
    let title: String
    var kind: Kind = .outlined
    var enabled: Bool = true
    var icon: String? = nil
    let action: () -> Void
    @Environment(\.palette) var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .text ? 6 : 14)
            .padding(.vertical, kind == .text ? 6 : 9)
            .background(background)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private var foreground: Color {
        switch kind {
        case .filled: return palette.onPrimary
        case .outlined: return palette.onSurfaceVariant
        case .text: return palette.primary
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .filled:
            RoundedRectangle(cornerRadius: 10).fill(palette.primary)
        case .outlined:
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(palette.outline)
        case .text:
            Color.clear
        }
    }
}

// ====== 通用小工具 ======

private func trimSlash(_ s: String) -> String {
    String(s.dropLast(while: { $0 == "/" }))
}

private func copyToClipboard(_ text: String) {
    UIPasteboard.general.string = text
}

private func looksLikeUrl(_ s: String) -> Bool {
    let t = s.trimmingCharacters(in: .whitespaces)
    return t.lowercased().hasPrefix("http://") ||
        t.lowercased().hasPrefix("https://") ||
        t.lowercased().hasPrefix("www.")
}

/// 拼成可跳转的 URL（与安卓 openInBrowser 同逻辑）
private func browserURL(_ s: String) -> URL? {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let target: String
    if looksLikeUrl(trimmed) && !trimmed.lowercased().hasPrefix("http") {
        target = "https://\(trimmed)"
    } else {
        target = trimmed
    }
    return URL(string: target)
}

// ====== 剪贴板 ======

private struct ClipboardToolCard: View {
    @Environment(\.palette) var palette
    @Environment(\.openURL) var openURL
    @State private var text: String?

    var body: some View {
        ToolCard(title: "剪贴板", hint: "进入本页时自动读取", icon: "doc.on.clipboard") {
            if let t = text, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(String(t.prefix(400)))
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(8)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    ToolButton(title: "复制", icon: "doc.on.doc") {
                        copyToClipboard(t)
                    }
                    if looksLikeUrl(t) {
                        ToolButton(title: "打开链接", kind: .filled) {
                            if let u = browserURL(t) { openURL(u) }
                        }
                    }
                }
            } else {
                Text("剪贴板是空的（或系统限制了读取），复制点东西再进来")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            text = UIPasteboard.general.string
        }
    }
}

// ====== 时间戳 ======

private let humanFormat: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    f.locale = Locale.current
    return f
}()

private struct TsResult {
    let display: String
    let copy: String
}

/// 双向互转：纯数字 → 人类可读；人类可读 → 秒/毫秒时间戳
private func convertTimestamp(_ input: String) -> TsResult? {
    let s = input.trimmingCharacters(in: .whitespaces)
    if s.isEmpty { return nil }
    if s.count == 10, s.allSatisfy({ $0.isNumber }), let v = Int(s) {
        return TsResult(display: humanFormat.string(from: Date(timeIntervalSince1970: Double(v))), copy: s)
    }
    if s.count == 13, s.allSatisfy({ $0.isNumber }), let v = Int(s) {
        return TsResult(display: humanFormat.string(from: Date(timeIntervalSince1970: Double(v) / 1000)), copy: s)
    }
    if let d = humanFormat.date(from: s) {
        let ms = Int(d.timeIntervalSince1970 * 1000)
        return TsResult(display: "秒：\(ms / 1000)　毫秒：\(ms)", copy: "\(ms)")
    }
    return nil
}

private struct TimestampCard: View {
    @Environment(\.palette) var palette
    @State private var input = ""
    @State private var now = Int(Date().timeIntervalSince1970)

    private var converted: TsResult? { convertTimestamp(input) }

    var body: some View {
        ToolCard(title: "时间戳", hint: "秒/毫秒与日期互转，点击即复制", icon: "clock") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前时间戳")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                    Text("\(now)")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                    Text("毫秒 \(now * 1000)")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                Spacer(minLength: 8)
                ToolButton(title: "复制") {
                    copyToClipboard("\(now)")
                }
            }

            TextField("输入时间戳或日期（如 2026-11-05 12:00:00）", text: $input, prompt: Text("输入时间戳或日期（如 2026-11-05 12:00:00）"))
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

            if let result = converted {
                HStack(alignment: .center) {
                    Text(result.display)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.primary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ToolButton(title: "复制", kind: .text) {
                        copyToClipboard(result.copy)
                    }
                }
            }
        }
        .task {
            while !Task.isCancelled {
                now = Int(Date().timeIntervalSince1970)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

// ====== 二维码（生成 + 相机扫描）======

private enum QRTool {
    private static let context = CIContext()

    static func generate(_ text: String) -> UIImage? {
        guard let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

private struct QrCodeCard: View {
    @Environment(\.palette) var palette
    @State private var text = ""
    @State private var scanning = false
    @State private var qrImage: UIImage?

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ToolCard(title: "二维码", hint: "生成 + 扫描（相机扫码）", icon: "qrcode") {
            TextField("要生成二维码的内容", text: $text, prompt: Text("要生成二维码的内容"))
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

            HStack(spacing: 8) {
                ToolButton(title: "扫一扫", kind: .filled, icon: "viewfinder") {
                    scanning = true
                }
                ToolButton(title: "复制内容", enabled: !trimmed.isEmpty) {
                    copyToClipboard(trimmed)
                }
                if looksLikeUrl(text) {
                    ToolButton(title: "打开") {
                        if let u = browserURL(text) { UIApplication.shared.open(u) }
                    }
                }
            }

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .accessibilityLabel("二维码")
            }
        }
        .task(id: text) {
            qrImage = trimmed.isEmpty ? nil : QRTool.generate(trimmed)
        }
        .fullScreenCover(isPresented: $scanning) {
            QRScannerSheet(
                onScan: { code in
                    text = code
                    scanning = false
                },
                onClose: { scanning = false }
            )
        }
    }
}

// ====== 相机扫码（AVCaptureSession 包装成 SwiftUI）======

private struct QRScannerSheet: View {
    let onScan: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            QRScannerRepresentable(onScan: onScan)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                Text("将二维码放入框内")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.black.opacity(0.5)))

                Spacer()
                    .frame(height: 48)
            }
        }
        .background(Color.black)
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {
        uiViewController.onScan = onScan
    }
}

private final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var configured = false
    private var handled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main {
                    if granted {
                        self?.startSession()
                    } else {
                        self?.showDenied()
                    }
                }
            }
        default:
            showDenied()
        }
    }

    private func startSession() {
        if configured {
            runSession()
            return
        }
        guard let device = AVCaptureDevice.default(for: .video) else {
            showDenied()
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            showDenied()
            return
        }
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
        }
        configured = true

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        runSession()
    }

    private func runSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    private func stopSession() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    /// 相机权限被拒：提示 + 跳系统设置（Info.plist 已有 NSCameraUsageDescription）
    private func showDenied() {
        guard view.subviews.isEmpty else { return }

        let label = UILabel()
        label.text = "需要相机权限才能扫描二维码"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 0

        var config = UIButton.Configuration.filled()
        config.title = "去设置"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.22)
        config.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 26, bottom: 9, trailing: 26)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])
    }

    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVCaptureMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !handled,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue,
              !value.isEmpty else { return }
        handled = true
        stopSession()
        onScan?(value)
    }
}

// ====== 随机数 / 随机决定 ======

private struct RandomCard: View {
    @Environment(\.palette) var palette
    @State private var minText = "1"
    @State private var maxText = "100"
    @State private var number: String?
    @State private var choices = "吃火锅,吃烧烤,吃面条,点外卖"
    @State private var picked: String?

    var body: some View {
        ToolCard(title: "随机数 / 随机决定", hint: "范围随机 + 抽签决定", icon: "shuffle") {
            HStack(spacing: 8) {
                TextField("最小", text: $minText, prompt: Text("最小"))
                    .keyboardType(.numberPad)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.onBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

                TextField("最大", text: $maxText, prompt: Text("最大"))
                    .keyboardType(.numberPad)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.onBackground)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

                ToolButton(title: "随机", kind: .filled) { roll() }
            }

            if let number {
                Text(number)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(palette.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            TextField("选项（逗号 / 顿号 / 空格分隔）", text: $choices, prompt: Text("选项（逗号 / 顿号 / 空格分隔）"))
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

            HStack(alignment: .center) {
                Text(picked.map { "👉 \($0)" } ?? "还没抽")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ToolButton(title: "抽一个", kind: .filled) { draw() }
            }
        }
    }

    private func roll() {
        guard let a = Int(minText.trimmingCharacters(in: .whitespaces)),
              let b = Int(maxText.trimmingCharacters(in: .whitespaces)),
              b >= a else { return }
        number = "\(Int.random(in: a...b))"
    }

    private func draw() {
        let list = choices
            .split { ch in
                ch == "," || ch == "，" || ch == "、" || ch == ";" || ch == "；" || ch.isWhitespace
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        picked = list.randomElement()
    }
}

// ====== URL 编解码 ======

/// 与 Java URLEncoder.encode(s, "UTF-8") 同口径（空格 → +）
private func javaUrlEncode(_ s: String) -> String? {
    var allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.")
    allowed.insert(charactersIn: "*")
    guard let encoded = s.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
    return encoded.replacingOccurrences(of: "%20", with: "+")
}

/// 与 Java URLDecoder.decode(s, "UTF-8") 同口径（+ → 空格）
private func javaUrlDecode(_ s: String) -> String? {
    s.replacingOccurrences(of: "+", with: "%20").removingPercentEncoding
}

private struct UrlCodecCard: View {
    @Environment(\.palette) var palette
    @State private var input = ""
    @State private var mode = 0   // 0=编码 1=解码

    private var trimmed: String { input.trimmingCharacters(in: .whitespaces) }

    private var result: String? {
        guard !trimmed.isEmpty else { return nil }
        return mode == 0 ? javaUrlEncode(trimmed) : javaUrlDecode(trimmed)
    }

    var body: some View {
        ToolCard(title: "URL 编解码", hint: "百分号编码 / 解码，一键复制", icon: "link") {
            TextField("要编码或解码的字符串", text: $input, prompt: Text("要编码或解码的字符串"))
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

            Picker("", selection: $mode) {
                Text("编码").tag(0)
                Text("解码").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let result {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode == 0 ? "编码" : "解码")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.onSurfaceVariant)
                        Text(result)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.onBackground)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ToolButton(title: "复制", kind: .text) {
                        copyToClipboard(result)
                    }
                }
            }
        }
    }
}

// ====== IP 查询 ======

private func ipv4RegexMatch(_ text: String) -> String? {
    guard let match = text.firstMatch(of: /\b(?:\d{1,3}\.){3}\d{1,3}\b/) else { return nil }
    let ip = String(match.output)
    let parts = ip.split(separator: ".")
    guard parts.count == 4, parts.allSatisfy({ (Int($0) ?? 999) <= 255 }) else { return nil }
    return ip
}

/// 公网 IP：多个数据源依次兜底（任一可用即可），返回 IPv4 文本
private func fetchPublicIp() async -> String? {
    let endpoints = [
        "https://api.ipify.org?format=json",
        "https://api.ipify.org",
        "https://myip.ipip.net/",
        "https://ddns.oray.com/checkip",
    ]
    for endpoint in endpoints {
        guard let u = URL(string: endpoint) else { continue }
        var req = URLRequest(url: u)
        req.timeoutInterval = 6
        guard let (data, resp) = try? await TrustSession.shared.data(for: req) else { continue }
        if let http = resp as? HTTPURLResponse, !(200..<400).contains(http.statusCode) { continue }
        guard let body = String(data: data, encoding: .utf8) else { continue }
        if let ip = ipv4RegexMatch(body) { return ip }
    }
    return nil
}

/// 本机局域网 IP（getifaddrs，优先 Wi-Fi 的 en0）
private func localIpAddress() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    defer { freeifaddrs(ifaddr) }

    var fallback: String?
    var ptr = ifaddr
    while let current = ptr {
        defer { ptr = current.pointee.ifa_next }
        let flags = Int32(current.pointee.ifa_flags)
        guard flags & (IFF_UP | IFF_RUNNING) != 0 else { continue }
        guard let addr = current.pointee.ifa_addr else { continue }
        guard Int32(addr.pointee.sa_family) == AF_INET else { continue }

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        guard getnameinfo(addr, socklen_t(MemoryLayout<sockaddr_in>.size),
                          &hostname, socklen_t(hostname.count),
                          nil, 0, NI_NUMERICHOST) == 0 else { continue }
        let ip = String(cString: hostname)
        if ip.hasPrefix("127.") { continue }

        let name = String(cString: current.pointee.ifa_name)
        if name == "en0" { return ip }
        if fallback == nil { fallback = ip }
    }
    return fallback
}

private struct IpCard: View {
    @Environment(\.palette) var palette
    @State private var publicIp: String?
    @State private var localIp: String?
    @State private var loading = false
    @State private var failed = false
    @State private var refreshKey = 0

    var body: some View {
        ToolCard(title: "IP 查询", hint: "公网 IP + 本机局域网地址", icon: "globe") {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("公网 IP")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                    Text(publicText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.onBackground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ToolButton(title: loading ? "查询中" : "重新查询", enabled: !loading) {
                    refreshKey += 1
                }
            }

            Text("本机 IP（局域网）：\(localIp ?? "-")")
                .font(.system(size: 13))
                .foregroundStyle(palette.onSurfaceVariant)
        }
        .task(id: refreshKey) {
            loading = true
            failed = false
            if refreshKey > 0 { publicIp = nil }
            let pub = await fetchPublicIp()
            publicIp = pub
            localIp = localIpAddress()
            failed = pub == nil
            loading = false
        }
    }

    private var publicText: String {
        if loading && publicIp == nil { return "查询中…" }
        if let publicIp { return publicIp }
        if failed { return "查询失败（网络不可达）" }
        return "-"
    }
}

// ====== 常用链接（镜像网页端 HOME_QUICK_LINKS）======

private struct QuickLink: Identifiable, Equatable {
    let name: String
    let url: String
    let uids: Set<Int>?
    var id: String { name }
    init(_ name: String, _ url: String, uids: Set<Int>? = nil) {
        self.name = name
        self.url = url
        self.uids = uids
    }
}

private let QUICK_LINKS: [QuickLink] = [
    QuickLink("Bilibili", "https://www.bilibili.com"),
    QuickLink("萌娘百科", "https://zh.moegirl.org.cn"),
    QuickLink("MC百科", "https://www.mcmod.cn"),
    QuickLink("DeepSeek", "https://chat.deepseek.com"),
    QuickLink("薇薇屏幕共享", "https://vdo.ninja/?view=kanweiweifuyan&e2ee#p=ZhiYanjuemi521!@!", uids: [1, 2]),
    QuickLink("恋恋屏幕共享", "https://vdo.ninja/?view=qetuoadghk&e2ee#p=ZhiYanjuemi521!@!", uids: [1, 2]),
    QuickLink("语雀知识库", "https://www.yuque.com/weiwei-hsvab/gxuke5"),
    QuickLink("520游戏库", "https://www.gamer520.com/"),
    QuickLink("SCP基金会", "https://scp-wiki-cn.wikidot.com/"),
]

private struct QuickLinksCard: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @Environment(\.openURL) var openURL

    private var links: [QuickLink] {
        QUICK_LINKS.filter { link in
            guard let uids = link.uids else { return true }
            return uids.contains(vm.userId)
        }
    }

    var body: some View {
        ToolCard(title: "常用链接", hint: "一键跳转浏览器打开", icon: "globe.asia.australia") {
            VStack(spacing: 0) {
                ForEach(links) { link in
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.primary)
                            .frame(width: 16, height: 16)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(palette.onBackground)
                                .lineLimit(1)
                            Text(link.url)
                                .font(.system(size: 11))
                                .foregroundStyle(palette.onSurfaceVariant)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ToolButton(title: "打开", kind: .text) {
                            if let u = browserURL(link.url) { openURL(u) }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
