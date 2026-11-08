import Foundation

/// 【副本】与主 App Core/Json.swift 完全一致 —— 扩展 target 不编译主 App 源码，
/// 所以把最小需要的 Json 助手复制一份进来（只读，勿在本目录之外引用）。
typealias Json = [String: Any]

enum JsonParse {
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
    func objects() -> [Json] {
        compactMap { $0 as? Json }
    }
}
