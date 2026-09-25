//
//  KeychainStore.swift
//  ASCII Broadcast
//
//  Stream keys live in the keychain and nowhere else: not in the session
//  document, not in logs, not in diagnostics, not in a crash report. The UI
//  only ever sees `hasStoredKey` and a redacted placeholder.
//

import Foundation
import Security

enum KeychainStore {

    private static let service = "com.vagabond.asciibroadcast.streamkeys"

    @discardableResult
    static func store(key: String, for account: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        remove(account: account)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        #endif
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func key(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func hasKey(for account: String) -> Bool {
        key(for: account)?.isEmpty == false
    }

    @discardableResult
    static func remove(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
