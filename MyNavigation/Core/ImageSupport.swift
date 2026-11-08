import Foundation

/// 相对路径（/api/files/...）→ 站点绝对地址（与安卓 ImageSupport.kt 对齐）
enum ImageBase {
    @MainActor static var baseUrl: String = ""
}

@MainActor
func resolveImg(_ path: String) -> String {
    if path.isEmpty { return path }
    if path.hasPrefix("http://") || path.hasPrefix("https://") { return path }
    let base = ImageBase.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if path.hasPrefix("/") { return base + path }
    return base + "/" + path
}
