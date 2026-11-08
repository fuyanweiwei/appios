import SwiftUI
import UIKit

// ====== P2-1/P2-4 记录模块「记一笔」通用表单（FeatureEditScreen.kt 对齐）======
// 字段完全由 FEATURE_CATALOG 驱动——有 options 的渲染成下拉，其余是文本框；
// 新增走 POST `/api/feature-data/{appType}/add`，编辑走 PUT `/{id}`（见 AppViewModel.saveFeature）。

struct FeatureEditScreen: View {
    let appType: String
    let title: String
    let row: Json?

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.palette) var palette

    @State private var values: [String: String]

    init(appType: String, title: String, row: Json?) {
        self.appType = appType
        self.title = title
        self.row = row
        // 编辑时预填 row 的值（org.json JSONObject.opt(...) 的等价判断）
        var prefill: [String: String] = [:]
        if let row {
            for f in featureDefOf(appType).fields {
                if let v = row[f.key], !(v is NSNull) {
                    let s = editValueText(v)
                    if !s.isEmpty && s != "null" { prefill[f.key] = s }
                }
            }
        }
        _values = State(initialValue: prefill)
    }

    private var def: FeatureDef { featureDefOf(appType) }
    private var isEdit: Bool { row != nil }

    private var editId: Int? {
        guard let row else { return nil }
        let id = row.optLong("id")
        return id > 0 ? id : nil
    }

    var body: some View {
        OverlayScaffold(title: isEdit ? "编辑 · \(title)" : "记一笔 · \(title)") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(def.emoji)
                        .font(.system(size: 22))
                    Text(isEdit ? "改完点底部保存" : "填几项就能存，其余留空")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.onSurfaceVariant)
                }

                // P2-2：角色记忆专属 —— AI 帮写（与网页 character_memory 同一套提示词/导入格式）
                if appType == "character_memory" {
                    CharMemoryAiBar(values: $values) { vm.showMessage($0) }
                        .padding(.top, 12)
                }

                Spacer(minLength: 14)

                ForEach(def.fields) { f in
                    fieldRow(f)
                }

                Spacer(minLength: 18)

                Button {
                    vm.saveFeature(appType: appType, id: editId, values: values)
                } label: {
                    Text(isEdit ? "保存修改" : "添加记录")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(palette.onPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(palette.primary)
                        )
                }
                .buttonStyle(.plain)

                if isEdit {
                    Text("留空的项不会被改动")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }
            .padding(16)
        }
    }

    // ---- 单个字段：有 options → Picker 菜单；否则文本框 ----

    @ViewBuilder
    private func fieldRow(_ f: FeatureField) -> some View {
        if f.options.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(f.label)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.onSurfaceVariant)
                TextField(f.label, text: valueBinding(f.key))
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(palette.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(palette.outline)
                            )
                    )
            }
            .padding(.vertical, 4)
        } else {
            HStack(spacing: 8) {
                Text(f.label)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.onSurfaceVariant)
                    .frame(width: 84, alignment: .leading)
                Picker(selectLabel(f), selection: selectBinding(f.key)) {
                    // 菜单 Picker 在 Form 外展示的是「选中项文本」，所以空态文案就是按钮文案
                    Text("请选择").tag("")
                    ForEach(f.options, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 13))
                .tint(palette.onSurfaceVariant)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(palette.outline)
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func selectLabel(_ f: FeatureField) -> String {
        let v = values[f.key] ?? ""
        return v.isEmpty ? "请选择" : v
    }

    private func valueBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }

    private func selectBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { values[key] ?? "" },
            set: { values[key] = $0 }
        )
    }
}

/// 任意 JSON 值 → 表单字符串（布尔 → true/false，与 Java toString 一致）
private func editValueText(_ v: Any) -> String {
    if let s = v as? String { return s }
    if let n = v as? NSNumber {
        if String(cString: n.objCType) == "c" { return n.boolValue ? "true" : "false" }
        return n.stringValue
    }
    if v is NSNull { return "null" }
    return String(describing: v)
}

/* ====== P2-2 角色记忆 · AI 帮写（与网页 character_memory.js 同一套提示词/导入格式） ====== */

/// AI 要补全的字段 key（与网页 CHAR_AI_FIELDS 一一对应）
private let CHAR_AI_KEYS = [
    "animeName", "animeType", "characterName", "characterType", "gender", "age",
    "height", "weight", "bloodType", "birthday", "voiceActor", "affiliation",
    "personality", "weapon", "hobbies", "overallScore", "appearanceScore",
    "strengthScore", "personalityScore", "popularityScore", "hotness",
    "reason", "wantFanfic", "imageUrl",
]

private let CHAR_AI_FIELD_DESC = [
    "animeName：动漫名称（必填，字符串）",
    "animeType：动漫类型（字符串，如 热血/恋爱/奇幻）",
    "characterName：角色名称（必填，字符串）",
    "characterType：角色类型（主角/配角/反派/路人）",
    "gender：性别（男/女/其他）",
    "age：年龄（字符串，如 16岁）",
    "height：身高（字符串，如 165cm）",
    "weight：体重（字符串，如 50kg）",
    "bloodType：血型（A/B/O/AB）",
    "birthday：生日（字符串，如 5月1日）",
    "voiceActor：声优（字符串）",
    "affiliation：所属（势力/组织，字符串）",
    "personality：性格（字符串，如 温柔/傲娇/腹黑）",
    "weapon：武器/技能（字符串）",
    "hobbies：喜好（字符串）",
    "overallScore：综合评分（0-100 的整数，必须与已填一致）",
    "appearanceScore：颜值评分（0-100 的整数）",
    "strengthScore：实力评分（0-100 的整数）",
    "personalityScore：性格评分（0-100 的整数）",
    "popularityScore：人气评分（0-100 的整数）",
    "hotness：热门度（0-100 的整数）",
    "reason：上榜理由（字符串）",
    "wantFanfic：愿意写同人（布尔，只能是 true 或 false）",
    "imageUrl：角色图片地址（没有可靠图片就填空字符串 \"\"）",
]

private let CHAR_AI_EXAMPLE =
    "[{\"animeName\":\"魔法少女小圆\",\"animeType\":\"奇幻\",\"characterName\":\"鹿目圆\"," +
        "\"characterType\":\"主角\",\"gender\":\"女\",\"age\":\"14岁\",\"height\":\"150cm\"," +
        "\"weight\":\"42kg\",\"bloodType\":\"A型\",\"birthday\":\"10月3日\",\"voiceActor\":\"悠木碧\"," +
        "\"affiliation\":\"见泷原中学\",\"personality\":\"温柔善良、重情义\",\"weapon\":\"灵魂宝石\"," +
        "\"hobbies\":\"做饭、和家人在一起\",\"overallScore\":95,\"appearanceScore\":92," +
        "\"strengthScore\":78,\"personalityScore\":96,\"popularityScore\":95,\"hotness\":88," +
        "\"reason\":\"为了守护重要的人甘愿付出一切\",\"wantFanfic\":true,\"imageUrl\":\"\"}]"

/// 生成提问词（单个角色版，字段要求与网页完全一致，AI 返回可直接两边通用）
private func buildCharAiPrompt(animeName: String, characterName: String, score: String) -> String {
    var line = "动漫《\(animeName)》 / 角色「\(characterName)」"
    let trimmedScore = score.trimmingCharacters(in: .whitespaces)
    if !trimmedScore.isEmpty { line += "，综合评分 \(trimmedScore)" }

    var s = "请帮我补全一条二次元角色词条，用于录入。请生成一个 JSON 对象。\n\n"
    s += "【已填写】\n\(line)\n\n"
    s += "【必须包含以下全部字段】\n"
    for d in CHAR_AI_FIELD_DESC { s += "- \(d)\n" }
    s += "\n【生成要求】\n"
    s += "1. 只返回一个 JSON 对象，不要任何解释文字，不要 markdown 代码块；\n"
    s += "2. animeName、characterName"
    if !trimmedScore.isEmpty { s += "、overallScore" }
    s += " 必须与上面完全一致，其余字段按该角色在原作中的真实设定补全；\n"
    s += "3. 0-100 的评分字段只能是整数，wantFanfic 只能是 true 或 false。\n"
    s += "例如：\(CHAR_AI_EXAMPLE)"
    return s
}

/// 容错解析：去掉代码块、截取数组段，支持「数组」或「单对象」两种返回
private func parseAiObjects(_ raw: String) -> [Json] {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty { return [] }
    s = s.replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
    s = s.replacingOccurrences(of: "```", with: "")
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    if let a = s.firstIndex(of: "["), let b = s.lastIndex(of: "]"), b > a {
        s = String(s[a...b])
    }
    if let arr = JsonParse.array(s) { return arr.objects() }
    if let obj = JsonParse.object(s) { return [obj] }
    return []
}

private struct CharMemoryAiBar: View {
    @Binding var values: [String: String]
    let onMessage: (String) -> Void
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    let anime = (values["animeName"] ?? "").trimmingCharacters(in: .whitespaces)
                    let name = (values["characterName"] ?? "").trimmingCharacters(in: .whitespaces)
                    if anime.isEmpty || name.isEmpty {
                        onMessage("先填好动漫名称和角色名称，再点「AI 帮写」")
                        return
                    }
                    let prompt = buildCharAiPrompt(
                        animeName: anime,
                        characterName: name,
                        score: values["overallScore"] ?? ""
                    )
                    UIPasteboard.general.string = prompt
                    onMessage("提问词已复制 → 去问 AI → 拿到 JSON 后点「粘贴导入」")
                } label: {
                    Text("AI 帮写")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(palette.outline)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    let text = UIPasteboard.general.string ?? ""
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onMessage("剪贴板是空的，先把 AI 返回的内容复制过来")
                        return
                    }
                    let objs = parseAiObjects(text)
                    if objs.isEmpty {
                        onMessage("没解析到 JSON，确认一下 AI 返回的内容")
                        return
                    }
                    // 优先取与当前角色同名的那条，否则取第一条
                    let target = (values["characterName"] ?? "").trimmingCharacters(in: .whitespaces)
                    let obj = objs.first(where: { $0.optString("characterName") == target }) ?? objs[0]
                    var filled = 0
                    for key in CHAR_AI_KEYS {
                        if let v = obj[key], !(v is NSNull) {
                            values[key] = editValueText(v)
                            filled += 1
                        }
                    }
                    onMessage(filled > 0 ? "已导入 \(filled) 个字段，检查后保存" : "JSON 里没有可识别的字段")
                } label: {
                    Text("粘贴导入")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(palette.outline)
                        )
                }
                .buttonStyle(.plain)
            }

            Text("流程：填动漫名+角色名 → AI 帮写 → 去问 AI → 粘贴导入 → 保存（生成的 JSON 也能直接粘回网页导入框）")
                .font(.system(size: 11))
                .foregroundStyle(palette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
