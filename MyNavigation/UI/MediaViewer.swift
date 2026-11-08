import SwiftUI
import Photos
import UIKit

// ====== 全屏图片查看器（对照 Android ui/MediaViewer.kt）======
// 黑底 TabView 翻页 + 页码 + 底部信息卡 + 双击 2.5x / 捏合 1-5x + 下载到相册

@MainActor struct MediaViewerScreen: View {
    let items: [MediaItem]
    let index: Int

    @EnvironmentObject var vm: AppViewModel
    @State private var current = 0
    @State private var saving = false

    private var currentItem: MediaItem? {
        guard items.indices.contains(current) else { return nil }
        return items[current]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !items.isEmpty {
                pager

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    bottomCard
                }
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear { current = min(max(index, 0), max(items.count - 1, 0)) }
    }

    // 左右滑动连续浏览
    private var pager: some View {
        TabView(selection: $current) {
            ForEach(items.indices, id: \.self) { i in
                ZoomablePhoto(item: items[i])
                    .tag(i)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                vm.popOverlay()
            } label: {
                Text("✕ 关闭")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if items.count > 1 {
                Text("\(current + 1) / \(items.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
            }

            Spacer()

            Color.clear.frame(width: 78, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // 底部信息卡：名称 / 上传者 / 标签 / 评分 + 下载按钮
    @MainActor
    private var bottomCard: some View {
        VStack(spacing: 10) {
            if let item = currentItem {
                VStack(spacing: 4) {
                    if !item.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(item.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                    }
                    HStack(spacing: 8) {
                        if !item.by.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text("上传：" + item.by)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        if item.score > 0 {
                            Text(String(repeating: "★", count: max(0, item.score)))
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: 0xFFC94D))
                        }
                        if !item.tags.trimmingCharacters(in: .whitespaces).isEmpty {
                            Text(item.tags)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
                .padding(.horizontal, 20)

                downloadButton(item)
            }
        }
    }

    @MainActor
    private func downloadButton(_ item: MediaItem) -> some View {
        Button {
            guard !saving else { return }
            saving = true
            let url = resolveImg(item.url)
            Task {
                do {
                    let data = try await vm.siteApi().getBytes(url)
                    let ok = await saveToWeiweiAlbum(data)
                    saving = false
                    vm.showMessage(ok ? "已保存到相册" : "保存失败")
                } catch {
                    saving = false
                    vm.showMessage("下载失败：\(error.localizedDescription)")
                }
            }
        } label: {
            Text(saving ? "保存中…" : "下载到相册")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.18)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(saving)
    }
}

// MARK: - 单图手势：双击 2.5x，放大后可捏合（1-5x）/拖动，复位则不影响翻页

@MainActor private struct ZoomablePhoto: View {
    let item: MediaItem

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize?
    @State private var pinchBase: CGFloat = 1
    @State private var pinching = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            SmartImage(url: resolveImg(item.url), contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if scale > 1 {
                        withAnimation(.easeOut(duration: 0.18)) {
                            scale = 1
                            offset = .zero
                        }
                    } else {
                        withAnimation(.easeOut(duration: 0.18)) {
                            scale = 2.5
                        }
                    }
                }
                // 放大前不接管横向拖动，翻页完全不受影响
                .simultaneousGesture(magnify(size: size))
                .simultaneousGesture(drag(size: size))
        }
        .padding(12)
    }

    private func magnify(size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !pinching {
                    pinching = true
                    pinchBase = scale
                }
                let next = min(max(pinchBase * value, 1), 5)
                scale = next
                if next <= 1.05 {
                    offset = .zero
                } else {
                    clampOffset(size: size)
                }
            }
            .onEnded { _ in
                pinching = false
                if scale <= 1.05 {
                    scale = 1
                    offset = .zero
                }
            }
    }

    private func drag(size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                if dragStart == nil { dragStart = offset }
                let start = dragStart ?? .zero
                offset = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
                clampOffset(size: size)
            }
            .onEnded { _ in dragStart = nil }
    }

    /// 拖动限制在放大溢出范围内
    private func clampOffset(size: CGSize) {
        let halfW = max(0, size.width * (scale - 1) / 2)
        let halfH = max(0, size.height * (scale - 1) / 2)
        offset.width = min(max(offset.width, -halfW), halfW)
        offset.height = min(max(offset.height, -halfH), halfH)
    }
}

// MARK: - 保存到相册（创建/复用「薇薇导航」相簿）

/// 相册写入（Photos）；未授权 / 图片解码失败返回 false
private func saveToWeiweiAlbum(_ data: Data) async -> Bool {
    guard let image = UIImage(data: data) else { return false }
    let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    guard status == .authorized || status == .limited else { return false }

    let saved: Bool = await withCheckedContinuation { cont in
        let album = fetchWeiweiAlbum()
        PHPhotoLibrary.shared().performChanges({
            let assetReq = PHAssetChangeRequest.creationRequestForAsset(from: image)
            guard let placeholder = assetReq.placeholderForCreatedAsset else { return }
            if let album, let change = PHAssetCollectionChangeRequest(for: album) {
                change.addAssets([placeholder] as NSArray)
            } else {
                let albumReq = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "薇薇导航")
                albumReq.addAssets([placeholder] as NSArray)
            }
        }, completionHandler: { ok, _ in
            cont.resume(returning: ok)
        })
    }
    return saved
}

/// 取「薇薇导航」相簿（没有就由上面的 performChanges 顺手创建）
private func fetchWeiweiAlbum() -> PHAssetCollection? {
    let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
    var found: PHAssetCollection?
    result.enumerateObjects { collection, _, stop in
        if collection.localizedTitle == "薇薇导航" {
            found = collection
            stop.pointee = true
        }
    }
    return found
}
