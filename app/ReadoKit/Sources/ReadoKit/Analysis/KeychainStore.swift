import Foundation
import Security

/// Key user của FR-21. UI không đọc key ra — chỉ `OpenAICompatClient` gọi `load`.
/// Một máy, một người dùng. Khi có login: namespace theo tài khoản, xoá key lúc logout, không upload.
public enum KeychainStore {
    private static let service = "app.reado.analysis-agent"

    public enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)

        public var errorDescription: String? {
            switch self {
            case let .saveFailed(status):
                "Không lưu được key (mã \(status))"
            }
        }
    }

    public static func save(agentID: String, apiKey: String) throws {
        let query = base(agentID)
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(apiKey.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    public static func load(agentID: String) -> String? {
        var query = base(agentID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        let key = String(data: data, encoding: .utf8)
        guard let key, !key.isEmpty else { return nil }
        return key
    }

    /// Có mục hay không — không kéo secret vào bộ nhớ (list Cài đặt không đọc key).
    public static func contains(agentID: String) -> Bool {
        var query = base(agentID)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    public static func delete(agentID: String) {
        SecItemDelete(base(agentID) as CFDictionary)
    }

    private static func base(_ agentID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: agentID,
        ]
    }
}
