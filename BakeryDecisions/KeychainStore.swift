import Foundation
import Security

enum KeychainStore {
    private static var query: [String: Any] { [kSecClass as String:kSecClassGenericPassword, kSecAttrService as String:"org.theaicompany.bakerydecisions", kSecAttrAccount as String:"user-entered-demo-api-key"] }
    static func read() -> String? {
        var q = query; q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    static func save(_ key: String) throws {
        let data = Data(key.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var q = query; q[kSecValueData as String] = data; q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly; q[kSecAttrSynchronizable as String] = false
            guard SecItemAdd(q as CFDictionary,nil) == errSecSuccess else { throw DemoError.message("Could not store the key in Keychain.") }; return
        }
        guard status == errSecSuccess else { throw DemoError.message("Could not update the key in Keychain.") }
    }
    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw DemoError.message("Could not remove the stored key.") }
    }
}
