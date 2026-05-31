//
//  KeychainStore.swift
//  cue
//

import Foundation
import Security

/// Minimal keychain wrapper for storing small secret strings (our JWT).
/// All operations use `kSecClassGenericPassword` scoped to the app bundle.
/// Marked `Sendable` + `nonisolated` so it can be constructed off the main
/// actor (e.g. from a background-actor context during app launch).
struct KeychainStore: Sendable {
    /// Service identifier that groups Cue's keychain entries under the app bundle.
    let service: String

    nonisolated init(service: String = "makarov.cue.auth") {
        self.service = service
    }

    /// Writes a string under the given account, replacing any existing value.
    /// Returns `true` when the write succeeds.
    @discardableResult
    nonisolated func set(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    /// Reads the string stored under the given account. Returns `nil` when missing.
    nonisolated func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)

        guard status == errSecSuccess, let data = dataRef as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Deletes the entry under the given account, succeeding silently if absent.
    nonisolated func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
