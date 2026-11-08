import SwiftUI
import PhotosUI
import UIKit

// ====== 发布日常：文字 + 配图（相册多选 / 拍照）（ComposeDailyScreen.kt 对齐）======

private let maxDailyImages = 9

struct ComposeDailyScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var title = ""
    @State private var content = ""
    @State private var tags = ""
    @State private var images: [Data] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    var body: some View {
        OverlayScaffold(title: "写日常", trailing: AnyView(publishButton)) {
            VStack(alignment: .leading, spacing: 12) {
                DailyField(label: "标题（可选）") {
                    TextField("", text: $title)
                        .frame(minHeight: 24)
                }

                DailyField(label: "此刻想说点什么…") {
                    TextEditor(text: $content)
                        .frame(height: 220)
                        .scrollContentBackground(.hidden)
                }

                imagesSection

                DailyField(label: "标签（空格分隔，如 #生活 #日常）") {
                    TextField("", text: $tags)
                        .frame(minHeight: 24)
                }

                Text("发布后会同步到网站的「日常」，所有登录用户可见；配图会自动上传到站点图床")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .padding(16)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            loadPicked(items)
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(
                onImage: { data in
                    if images.count < maxDailyImages {
                        images.append(data)
                    }
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - 顶栏发布按钮（上传中转圈）

    @MainActor
    private var publishButton: some View {
        Button {
            vm.composeDaily(title: title, content: content, tags: tags, images: images)
        } label: {
            HStack(spacing: 5) {
                if vm.uploading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(palette.onPrimary)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                }
                Text(vm.uploading ? "上传中" : "发布")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(palette.onPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.primary))
        }
        .buttonStyle(.plain)
        .disabled(vm.uploading)
        .opacity(vm.uploading ? 0.7 : 1)
    }

    // MARK: - 配图区

    @MainActor
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("配图（\(images.count)/\(maxDailyImages)）")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.onBackground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: max(1, maxDailyImages - images.count),
                    matching: .images
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 14))
                        Text("相册").font(.system(size: 13))
                    }
                    .foregroundStyle(palette.onSecondaryContainer)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(palette.secondaryContainer))
                }
                .disabled(images.count >= maxDailyImages || vm.uploading)
                .opacity(images.count >= maxDailyImages || vm.uploading ? 0.5 : 1)

                Button {
                    takePhoto()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill").font(.system(size: 14))
                        Text("拍照").font(.system(size: 13))
                    }
                    .foregroundStyle(palette.onSecondaryContainer)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(palette.secondaryContainer))
                }
                .buttonStyle(.plain)
                .disabled(images.count >= maxDailyImages || vm.uploading)
                .opacity(images.count >= maxDailyImages || vm.uploading ? 0.5 : 1)
            }

            if !images.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    ForEach(images.indices, id: \.self) { idx in
                        ZStack(alignment: .topTrailing) {
                            if let ui = UIImage(data: images[idx]) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.15))
                            }
                            Button {
                                images.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(palette.surface)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(Color.black.opacity(0.45)))
                            }
                            .buttonStyle(.plain)
                            .padding(5)
                        }
                        .frame(height: 96)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - 拍照

    @MainActor
    private func takePhoto() {
        guard images.count < maxDailyImages else {
            vm.showMessage("最多 \(maxDailyImages) 张配图")
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            vm.showMessage("无法调用相机：当前设备不支持")
            return
        }
        showCamera = true
    }

    // MARK: - 相册多选 → Data

    @MainActor
    private func loadPicked(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if images.count >= maxDailyImages { break }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    images.append(data)
                }
            }
            pickerItems = []
        }
    }
}

// MARK: - 相机（UIImagePickerController 包装，需 NSCameraUsageDescription）

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onImage(data)
            }
            parent.onCancel()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - 小工具

/// 标签 + 描边输入框（OutlinedTextField 等价）
private struct DailyField<Content: View>: View {
    let label: String
    @Environment(\.palette) var palette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(palette.onSurfaceVariant)

            content
                .font(.system(size: 15))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(palette.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.outline, lineWidth: 1)
                )
        }
    }
}
