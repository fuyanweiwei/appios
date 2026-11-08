import SwiftUI

// ====== 反馈（FeedbackScreen.kt 对齐）：需求表单 + 应用内星级评分 ======

private let FEEDBACK_TYPES = ["新功能需求", "旧功能变更", "优化或美化", "bug修正"]
private let FEEDBACK_LEVELS = ["极低", "低", "中", "高", "紧急"]

struct FeedbackScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var type = ""
    @State private var level = "中"
    @State private var content = ""

    var body: some View {
        OverlayScaffold(title: "反馈") {
            VStack(spacing: 14) {
                Text("你的建议会直接进入待处理列表，并邮件通知站主")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)

                FormCard {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "需求类型（必选）")
                        Picker("", selection: $type) {
                            Text("请选择").tag("")
                            ForEach(FEEDBACK_TYPES, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "需求程度")
                        Picker("", selection: $level) {
                            ForEach(FEEDBACK_LEVELS, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "描述（必填）")
                        ZStack(alignment: .topLeading) {
                            if content.isEmpty {
                                Text("遇到了什么问题 / 想要什么功能…")
                                    .font(.system(size: 14))
                                    .foregroundStyle(palette.onSurfaceVariant.opacity(0.75))
                                    .padding(.top, 13)
                                    .padding(.leading, 13)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $content)
                                .font(.system(size: 14))
                                .foregroundStyle(palette.onBackground)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(height: 160)
                                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))
                        }
                    }

                    Button {
                        vm.submitFeedback(type: type, level: level, content: content)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 15))
                            Text("提交反馈")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(palette.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 10).fill(palette.primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(type.isEmpty || content.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                RatingCard()
            }
            .padding(16)
        }
    }
}

// ====== 应用内星级评分 ======

private struct RatingCard: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var score = 0
    @State private var reason = ""

    var body: some View {
        FormCard {
            Text("给 App 打分")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(palette.onBackground)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("1–5 星，评分会汇总到站点的功能评分")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        score = star
                    } label: {
                        Image(systemName: star <= score ? "star.fill" : "star")
                            .font(.system(size: 24))
                            .foregroundStyle(star <= score ? palette.primary : palette.onSurfaceVariant)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star) 星")
                }
                Spacer(minLength: 8)
                Text(score > 0 ? "\(score) / 5" : "未评分")
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
            }

            TextField("想说点什么（可选）", text: $reason, prompt: Text("想说点什么（可选）"))
                .font(.system(size: 14))
                .foregroundStyle(palette.onBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(palette.outline))

            Button {
                vm.submitAppRating(score: score, reason: reason)
            } label: {
                Text("提交评分")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(palette.outline)
                    )
            }
            .buttonStyle(.plain)
            .disabled(score <= 0)
        }
    }
}

// ====== 小组件 ======

private struct FormCard<Content: View>: View {
    @Environment(\.palette) var palette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

private struct SectionLabel: View {
    let text: String
    @Environment(\.palette) var palette

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
