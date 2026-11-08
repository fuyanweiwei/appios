import SwiftUI

// ====== 骨架屏 / 失败态 / 空态（Skeleton.kt 对齐）======

struct SkeletonBox: View {
    var cornerRadius: CGFloat = 10
    @State private var pulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(pulsing ? 0.10 : 0.22))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

struct SkeletonCards: View {
    var count: Int = 3
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBox().frame(height: 18).frame(maxWidth: .infinity)
                    SkeletonBox().frame(height: 14)
                    SkeletonBox().frame(height: 14).frame(width: 180)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemBackground)))
            }
        }
    }
}

/// 加载失败态（Q-3）：文案 + 重试按钮
struct ErrorState: View {
    let message: String
    var retry: (() -> Void)?
    @Environment(\.palette) var palette

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 34))
                .foregroundStyle(palette.outline)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let retry {
                Button(action: retry) {
                    Text("重试")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(palette.primary))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// 空态（emoji + 一句话）
struct EmptyState: View {
    let emoji: String
    let text: String
    @Environment(\.palette) var palette

    var body: some View {
        VStack(spacing: 10) {
            Text(emoji).font(.system(size: 44))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(palette.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}
