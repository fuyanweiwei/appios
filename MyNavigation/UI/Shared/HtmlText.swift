import SwiftUI
import UIKit

// ====== 网站贴板是 HTML（contenteditable）：轻量 HTML → AttributedString 渲染 + HTML 编辑器 ======

func htmlToAttributedString(_ html: String) -> AttributedString {
    guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return AttributedString("") }
    var result = AttributedString("")
    var bold = false
    var italic = false
    var underline = false
    var strike = false
    let s = html
    var i = s.startIndex

    func tagEnd(_ from: String.Index) -> String.Index {
        if let t = s[from...].firstIndex(of: ">") { return s.index(after: t) }
        return s.endIndex
    }

    while i < s.endIndex {
        if s[i...].hasPrefix("<br") || s[i...].hasPrefix("<BR") {
            result.append(AttributedString("\n"))
            i = tagEnd(i)
        } else if s[i...].hasPrefix("</p") || s[i...].hasPrefix("</div") || s[i...].hasPrefix("</li") {
            if i > s.startIndex { result.append(AttributedString("\n")) }
            i = tagEnd(i)
        } else if s[i...].hasPrefix("<b") || s[i...].hasPrefix("<strong") {
            bold = true; i = tagEnd(i)
        } else if s[i...].hasPrefix("</b") || s[i...].hasPrefix("</strong") {
            bold = false; i = tagEnd(i)
        } else if s[i...].hasPrefix("<i") || s[i...].hasPrefix("<em") {
            italic = true; i = tagEnd(i)
        } else if s[i...].hasPrefix("</i") || s[i...].hasPrefix("</em") {
            italic = false; i = tagEnd(i)
        } else if s[i...].hasPrefix("<u") {
            underline = true; i = tagEnd(i)
        } else if s[i...].hasPrefix("</u") {
            underline = false; i = tagEnd(i)
        } else if s[i...].hasPrefix("<s") || s[i...].hasPrefix("<del") {
            strike = true; i = tagEnd(i)
        } else if s[i...].hasPrefix("</s") || s[i...].hasPrefix("</del") {
            strike = false; i = tagEnd(i)
        } else if s[i...].hasPrefix("<") {
            i = tagEnd(i)
        } else {
            let next = s[i...].firstIndex(of: "<") ?? s.endIndex
            var text = String(s[i..<next])
            text = unescapeHtml(text)
            text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            var piece = AttributedString(text)
            if bold { piece.inlinePresentationIntent = .stronglyEmphasized }
            if italic { piece.inlinePresentationIntent = (piece.inlinePresentationIntent ?? []).union(.emphasized) }
            if underline { piece.underlineStyle = .single }
            if strike { piece.strikethroughStyle = .single }
            result.append(piece)
            i = next
        }
    }
    return result
}

private func unescapeHtml(_ t: String) -> String {
    t.replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
}

/// 编辑态显示：去掉 <div>/<p> 块级标签，<br> 转为换行
func htmlToEditText(_ html: String) -> String {
    guard !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "" }
    var t = html
    t = t.replacingOccurrences(of: "</?p[^>]*>", with: "", options: .regularExpression)
    t = t.replacingOccurrences(of: "</?div[^>]*>", with: "", options: .regularExpression)
    t = t.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
    t = t.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// 编辑态 → 保存的 HTML：换行转 <br>，保留行内标签
func editTextToHtml(_ text: String) -> String {
    text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "<br>")
}

/// 卡片摘要：去标签 + 截断
func htmlToPlain(_ html: String, max: Int = 160) -> String {
    let plain = String(htmlToAttributedString(html).characters)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    return plain.count <= max ? plain : String(plain.prefix(max)) + "…"
}

/// HTML 文本渲染（贴板/专栏内容）
struct HtmlText: View {
    let html: String
    var font: Font = .system(size: 15)
    var color: Color = .primary
    @Environment(\.palette) var palette

    var body: some View {
        Text(htmlToAttributedString(html))
            .font(font)
            .foregroundStyle(color)
            .textSelection(.enabled)
    }
}

/// 简单 HTML 编辑器：内容存 HTML，工具条对**真实选区**包裹标签（B/I/U/S/↵）
struct HtmlEditor: View {
    let html: String
    let onHtmlChange: (String) -> Void
    var placeholder: String = "写点什么…支持加粗等排版"
    @Environment(\.palette) var palette
    @State private var text: String = ""
    @State private var initialized = false
    @State private var editorRef: UITextView?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                toolBtn("B", bold: true) { wrap("<b>", "</b>") }
                toolBtn("I", bold: false) { wrap("<i>", "</i>") }
                toolBtn("U", bold: false) { wrap("<u>", "</u>") }
                toolBtn("S", bold: false) { wrap("<s>", "</s>") }
                toolBtn("↵", bold: false) { insertBreak() }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(palette.surfaceVariant.opacity(0.6))

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                HtmlTextEditor(text: $text, placeholder: placeholder, onRef: { editorRef = $0 })
                    .frame(minHeight: 140)
                    .background(palette.surface)
            }
                .onChange(of: text) { _, newValue in
                    guard initialized else { return }
                    onHtmlChange(editTextToHtml(newValue))
                }
                .onAppear {
                    if !initialized {
                        text = htmlToEditText(html)
                        initialized = true
                    }
                }
                .onChange(of: html) { _, newValue in
                    let edit = htmlToEditText(newValue)
                    if edit != text { text = edit }
                }

            Text("换行会存为 <br>，加粗等行内标签与网页互通")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.top, 4)
        }
    }

    /// 对真实选区包裹标签；无选区则插入空标签对并把光标置于中间
    private func wrap(_ open: String, _ close: String) {
        guard let tv = editorRef else { return }
        let ns = tv.text as NSString
        let range = tv.selectedRange
        let selected = ns.substring(with: range)
        let newText = (ns.substring(to: range.location) as String)
            + open + selected + close
            + ns.substring(from: range.location + range.length)
        let cursor = range.location + open.count + selected.count + close.count
        tv.text = newText
        tv.selectedRange = NSRange(location: cursor, length: 0)
        text = newText
        tv.becomeFirstResponder()
        onHtmlChange(editTextToHtml(newText))
    }

    private func insertBreak() {
        guard let tv = editorRef else { return }
        let ns = tv.text as NSString
        let at = tv.selectedRange.location
        let newText = ns.substring(to: at) + "<br>" + ns.substring(from: at)
        tv.text = newText
        tv.selectedRange = NSRange(location: at + 4, length: 0)
        text = newText
        tv.becomeFirstResponder()
        onHtmlChange(editTextToHtml(newText))
    }

    @ViewBuilder
    private func toolBtn(_ label: String, bold: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: bold ? .bold : .medium))
                .foregroundStyle(palette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(palette.surface))
        }
        .buttonStyle(.plain)
    }
}

/// 带选区感知的 UITextView 包装
struct HtmlTextEditor: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onRef: (UITextView) -> Void

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 15)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        tv.delegate = context.coordinator
        tv.alwaysBounceVertical = true
        onRef(tv)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text {
            tv.text = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: HtmlTextEditor
        init(_ parent: HtmlTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
    }
}
