import Foundation

/// 与安卓端 org.json 对齐的轻量 JSON 助手。
/// 服务端返回一律 JSONSerialization 解析为 [String: Any] / [Any]，
/// 各处沿用 Kotlin 的 optXxx 命名，方便与安卓代码逐行对照。
typealias Json = [String: Any]

enum JsonParse {
    /// 解析对象；失败返回 nil（调用方按“鉴权页/格式异常”处理，与安卓一致）
    static func object(_ text: String) -> Json? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? Json
    }

    static func array(_ text: String) -> [Any]? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [Any]
    }

    static func encode(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }
}

extension Json {
    func optString(_ key: String, _ def: String = "") -> String {
        guard let v = self[key] else { return def }
        if let s = v as? String { return s }
        if v is NSNull { return def }
        if let n = v as? NSNumber { return n.stringValue }
        return def
    }

    func optInt(_ key: String, _ def: Int = 0) -> Int {
        guard let v = self[key] else { return def }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s) { return i }
        return def
    }

    func optLong(_ key: String, _ def: Int = 0) -> Int {
        guard let v = self[key] else { return def }
        if let n = v as? NSNumber { return n.intValue }
        if let s = v as? String, let i = Int(s) { return i }
        return def
    }

    func optDouble(_ key: String, _ def: Double = 0) -> Double {
        guard let v = self[key] else { return def }
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String, let d = Double(s) { return d }
        return def
    }

    func optBoolean(_ key: String, _ def: Bool = false) -> Bool {
        guard let v = self[key] else { return def }
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.boolValue }
        if let s = v as? String {
            if s == "true" { return true }
            if s == "false" { return false }
        }
        return def
    }

    func optJSONObject(_ key: String) -> Json? {
        self[key] as? Json
    }

    func optJSONArray(_ key: String) -> [Any]? {
        self[key] as? [Any]
    }

    /// 可变副本（模拟 Kotlin JSONObject.put 后复用的语义）
    func mutable() -> Json { self }

    func putting(_ key: String, _ value: Any?) -> Json {
        var copy = self
        if let value {
            copy[key] = value
        } else {
            copy.removeValue(forKey: key)
        }
        return copy
    }
}

extension [Any] {
    /// 数组元素逐个取对象（对应 Kotlin arr.optJSONObject(i)）
    func objects() -> [Json] {
        compactMap { $0 as? Json }
    }
}
