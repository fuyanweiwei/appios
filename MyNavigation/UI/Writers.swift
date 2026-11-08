import SwiftUI

// ====== 写作类覆盖层：专栏发布 / 专栏详情 / 商品上架（Writers.kt 对齐）======

// MARK: - 写 / 编辑专栏（只能编辑自己的：入口只在自己的文章上出现）

struct ComposeColumnScreen: View {
    let id: Int?
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var titleText: String
    @State private var contentText: String
    @State private var typeText: String

    private let columnTypes = ["攻略", "感想", "漫谈", "推荐", "其他"]

    init(id: Int?, title: String, content: String, type: String) {
        self.id = id
        _titleText = State(initialValue: title)
        _contentText = State(initialValue: content)
        _typeText = State(initialValue: type)
    }

    private var isEdit: Bool { id != nil }

    var body: some View {
        OverlayScaffold(title: isEdit ? "编辑专栏" : "写专栏") {
            VStack(alignment: .leading, spacing: 12) {
                ColumnField(label: "标题") {
                    TextField("", text: $titleText)
                        .frame(minHeight: 24)
                }

                HStack(spacing: 6) {
                    Text("类型：")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.onSurfaceVariant)
                    ForEach(columnTypes, id: \.self) { t in
                        let selected = typeText == t
                        Button {
                            typeText = t
                        } label: {
                            Text(t)
                                .font(.system(size: 13))
                                .foregroundStyle(selected ? palette.onPrimary : palette.onSurfaceVariant)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule().fill(selected ? palette.primary : palette.surfaceVariant)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                ColumnField(label: "正文（支持换行，网页端可继续排版）") {
                    TextEditor(text: $contentText)
                        .frame(height: 280)
                        .scrollContentBackground(.hidden)
                }

                Button {
                    vm.saveColumn(id: id, title: titleText, content: contentText, type: typeText)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 13))
                        Text(isEdit ? "保存修改" : "发布专栏")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(palette.onPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(palette.primary))
                }
                .buttonStyle(.plain)

                Text("与网站一致：发布后会记录动态并计入成就；只有自己能改自己的专栏。")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .padding(16)
        }
    }
}

// MARK: - 专栏详情：点击查看全文（自己的可进编辑）

struct ColumnDetailScreen: View {
    let col: Json
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @MainActor
    private var mine: Bool { col.optLong("userId") == vm.userId }

    private var typeLabel: String {
        let t = col.optString("type")
        return t.isEmpty ? "专栏" : t
    }

    var body: some View {
        OverlayScaffold(title: "专栏详情") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(typeLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(palette.primaryContainer))

                    if mine {
                        Button {
                            vm.popOverlay()
                            vm.pushOverlay(
                                .composeColumn(
                                    id: col.optLong("id"),
                                    title: col.optString("title"),
                                    content: col.optString("content"),
                                    type: col.optString("type", "其他")
                                )
                            )
                        } label: {
                            Text("编辑")
                                .font(.system(size: 13))
                                .foregroundStyle(palette.primary)
                                .padding(4)
                                .frame(minHeight: 32)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(col.optString("title", "无标题"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.onBackground)
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    Text(vm.userName(col.optLong("userId")))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                    Text(absTimeText(col.optString("createdAt")))
                        .font(.system(size: 12))
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                .padding(.top, 6)

                let html = col.optString("content")
                HtmlText(
                    html: html.isEmpty ? "（无内容）" : html,
                    font: .system(size: 15),
                    color: palette.onBackground
                )
                .padding(.top, 14)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 24)
            }
            .padding(16)
        }
    }
}

// MARK: - 商城上架 / 编辑自己的商品

struct GiftEditScreen: View {
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette
    @State private var name: String
    @State private var icon: String
    @State private var type: String
    @State private var cost: String
    @State private var stock: String
    @State private var desc: String
    @State private var active: Bool
    private let giftId: Int?

    init(gift: Json?) {
        giftId = gift?.optLong("id")
        _name = State(initialValue: gift?.optString("name") ?? "")
        _icon = State(initialValue: gift?.optString("icon") ?? "fa-gift")
        _type = State(initialValue: gift?.optString("type") ?? "")
        _cost = State(initialValue: gift.map { "\($0.optInt("coinsCost", 0))" } ?? "0")
        _stock = State(initialValue: gift.map { "\($0.optInt("stock", -1))" } ?? "-1")
        _desc = State(initialValue: gift?.optString("message") ?? "")
        _active = State(initialValue: gift?.optBoolean("isActive", true) ?? true)
    }

    private var isEdit: Bool { giftId != nil }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        OverlayScaffold(title: isEdit ? "编辑我的商品" : "上架商品") {
            VStack(alignment: .leading, spacing: 12) {
                ColumnField(label: "名称 *") {
                    TextField("", text: $name)
                        .frame(minHeight: 24)
                }
                ColumnField(label: "图标（emoji 或 fa-xxx）") {
                    TextField("", text: $icon)
                        .frame(minHeight: 24)
                }
                ColumnField(label: "类型") {
                    TextField("", text: $type)
                        .frame(minHeight: 24)
                }
                ColumnField(label: "金币价格") {
                    TextField("", text: $cost)
                        .keyboardType(.numberPad)
                        .frame(minHeight: 24)
                }
                ColumnField(label: "库存（-1 不限）") {
                    TextField("", text: $stock)
                        .keyboardType(.numberPad)
                        .frame(minHeight: 24)
                }
                ColumnField(label: "描述") {
                    TextEditor(text: $desc)
                        .frame(height: 110)
                        .scrollContentBackground(.hidden)
                }

                HStack(spacing: 8) {
                    Text("上架中")
                        .font(.system(size: 14))
                        .foregroundStyle(palette.onBackground)
                    Toggle("", isOn: $active)
                        .labelsHidden()
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44)

                Button {
                    vm.saveGift(
                        id: giftId,
                        name: name,
                        icon: icon,
                        type: type,
                        cost: Int(cost) ?? 0,
                        stock: Int(stock) ?? -1,
                        message: desc,
                        active: active
                    )
                } label: {
                    Text(isEdit ? "保存" : "上架")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 10).fill(palette.primary))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
            }
            .padding(16)
        }
    }
}

// MARK: - 小工具

/// 标签 + 描边输入框（OutlinedTextField 等价）
private struct ColumnField<Content: View>: View {
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

/// 安卓：createdAt.replace('T', ' ').take(16)
private func absTimeText(_ raw: String) -> String {
    String(raw.replacingOccurrences(of: "T", with: " ").prefix(16))
}
