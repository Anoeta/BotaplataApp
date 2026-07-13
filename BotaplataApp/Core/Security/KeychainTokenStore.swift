import Foundation
import Security

actor KeychainTokenStore: TokenStoreProtocol {
    private let service = "fr.ios.BotaplataApp.auth"
    private let refreshAccount = "refresh-token"
    private let installationAccount = "installation-id"
    private let deviceAccount = "device-id"

    func saveRefreshToken(_ token: String) throws { try save(token, account: refreshAccount) }
    func readRefreshToken() throws -> String? { try read(account: refreshAccount) }
    func deleteRefreshToken() throws { try delete(account: refreshAccount) }
    func installationID() throws -> String {
        if let existing = try read(account: installationAccount) { return existing }
        let generated = UUID().uuidString
        try save(generated, account: installationAccount)
        return generated
    }
    func saveDeviceID(_ deviceID: String?) throws { if let deviceID { try save(deviceID, account: deviceAccount) } else { try delete(account: deviceAccount) } }
    func readDeviceID() throws -> String? { try read(account: deviceAccount) }
    func purgeSession() throws { try delete(account: refreshAccount); try delete(account: deviceAccount) }

    private func query(account: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
    private func save(_ value: String, account: String) throws {
        try delete(account: account)
        var item = query(account: account); item[kSecValueData as String] = Data(value.utf8); item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil); guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }
    private func read(account: String) throws -> String? {
        var item = query(account: account); item[kSecReturnData as String] = true; item[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?; let status = SecItemCopyMatching(item as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError.unhandled(status) }
        return String(data: data, encoding: .utf8)
    }
    private func delete(account: String) throws {
        let status = SecItemDelete(query(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unhandled(status) }
    }
}

enum KeychainError: Error, Equatable { case unhandled(OSStatus) }
