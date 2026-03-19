import Foundation
import Security

/// 用 iOS Keychain 安全儲存所有敏感資訊
enum KeychainManager {
    private static let service = "com.meetingrecorder"

    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String:   data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Typed keys

    /// 使用者 Email（僅作識別顯示用）
    static var userEmail: String? {
        get { load(forKey: "userEmail") }
        set { newValue.map { save($0, forKey: "userEmail") } ?? delete(forKey: "userEmail") }
    }

    /// AssemblyAI API Key（語音轉文字 + 說話者辨識）
    static var assemblyaiKey: String? {
        get { load(forKey: "assemblyaiKey") }
        set { newValue.map { save($0, forKey: "assemblyaiKey") } ?? delete(forKey: "assemblyaiKey") }
    }

    /// Claude API Key（會議摘要）
    static var claudeKey: String? {
        get { load(forKey: "claudeKey") }
        set { newValue.map { save($0, forKey: "claudeKey") } ?? delete(forKey: "claudeKey") }
    }

    /// 是否已完成初始設定
    static var isSetupComplete: Bool {
        guard let ak = assemblyaiKey, !ak.isEmpty,
              let ck = claudeKey, !ck.isEmpty else { return false }
        return true
    }

    static func clearAll() {
        delete(forKey: "userEmail")
        delete(forKey: "assemblyaiKey")
        delete(forKey: "claudeKey")
    }
}
