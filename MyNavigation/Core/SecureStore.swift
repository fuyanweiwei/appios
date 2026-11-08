import Foundation
import Security

/// B0-8 敏感存储的 iOS 等价实现：敏感项（Token / 防火墙密码）走 Keychain，
/// 其余走 UserDefaults（App Group 供小组件共享）。
/// 设计与安卓 SecureStore 一致：**功能优先**，任何一步失败都退回普通存储，绝不把用户锁在门外。
enum SecureStore {

    private static let service = "com.weiwei.mynavigation.secrets"

    static func setSecret(_ value: String, for key: String) {
        if value.isEmpty {
            deleteSecret(key)
            return
        }
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        if status != errSecSuccess {
            // Keychain 不可用（罕见）：退回明文 UserDefaults，功能不受影响
            UserDefaults.standard.set(value, forKey: "fallback_secret_\(key)")
        }
    }

    static func secret(_ key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let text = String(data: data, encoding: .utf8) {
            return text
        }
        return UserDefaults.standard.string(forKey: "fallback_secret_\(key)") ?? ""
    }

    static func deleteSecret(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: "fallback_secret_\(key)")
    }
}
