import Foundation

protocol TokenStoreProtocol: Sendable {
    func saveRefreshToken(_ token: String) async throws
    func readRefreshToken() async throws -> String?
    func deleteRefreshToken() async throws
    func installationID() async throws -> String
    func saveDeviceID(_ deviceID: String?) async throws
    func readDeviceID() async throws -> String?
    func purgeSession() async throws
}

actor InMemoryTokenStore: TokenStoreProtocol {
    private var refreshToken: String?
    private var deviceID: String?
    private var storedInstallationID: String
    init(installationID: String = "fixture-installation-id") { storedInstallationID = installationID }
    func saveRefreshToken(_ token: String) { refreshToken = token }
    func readRefreshToken() -> String? { refreshToken }
    func deleteRefreshToken() { refreshToken = nil }
    func installationID() -> String { storedInstallationID }
    func saveDeviceID(_ deviceID: String?) { self.deviceID = deviceID }
    func readDeviceID() -> String? { deviceID }
    func purgeSession() { refreshToken = nil; deviceID = nil }
}
