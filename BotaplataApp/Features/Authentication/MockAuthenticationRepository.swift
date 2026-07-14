import Foundation

actor MockAuthenticationRepository: AuthenticationRepository {
    enum Scenario: Sendable { case happyPath, invalidCredentials, serverUnavailable, rateLimited, expiredChallenge, tooManyAttempts, refreshRevoked, deviceRevoked, offline }
    private var scenario: Scenario
    private var session: AuthenticatedSession?
    private(set) var refreshCallCount = 0
    init(scenario: Scenario = .happyPath) { self.scenario = scenario }
    func setScenario(_ scenario: Scenario) { self.scenario = scenario }
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge {
        switch scenario { case .invalidCredentials: throw AuthenticationError.invalidCredentials; case .serverUnavailable: throw AuthenticationError.serverUnavailable; case .rateLimited: throw AuthenticationError.rateLimited; case .expiredChallenge: return AuthenticationFixtures.expiredChallenge; default: return AuthenticationFixtures.validChallenge }
    }
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession {
        if scenario == .deviceRevoked { throw AuthenticationError.deviceRevoked }
        if scenario == .tooManyAttempts { throw AuthenticationError.tooManyAttempts }
        if scenario == .expiredChallenge || challengeID.contains("expired") { throw AuthenticationError.challengeExpired }
        guard code == "123456" else { throw AuthenticationError.invalidTwoFactorCode }
        let s = AuthenticationFixtures.successfulSession; session = s; return s
    }
    func refresh(refreshToken: String, installationID: String) async throws -> AuthenticatedSession {
        refreshCallCount += 1
        switch scenario { case .refreshRevoked: throw AuthenticationError.refreshRevoked; case .deviceRevoked: throw AuthenticationError.deviceRevoked; case .offline: throw AuthenticationError.offline; default: let s = AuthenticationFixtures.successfulSession; session = s; return s }
    }
    func logout(accessToken: String?) async { session = nil }
    func authorizedDevices(accessToken: String) async throws -> [AuthorizedDevice] { [AuthenticationFixtures.device] }
    func revokeDevice(id: String, accessToken: String) async throws -> DeviceRevocationResult { session = nil; return DeviceRevocationResult(revokedDeviceID: id, currentDeviceRevoked: id == AuthenticationFixtures.device.id) }
}
