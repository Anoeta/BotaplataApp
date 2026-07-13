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
    func refresh(refreshToken: String) async throws -> AuthenticatedSession {
        refreshCallCount += 1
        switch scenario { case .refreshRevoked: throw AuthenticationError.refreshRevoked; case .deviceRevoked: throw AuthenticationError.deviceRevoked; case .offline: throw AuthenticationError.offline; default: let s = AuthenticationFixtures.successfulSession; session = s; return s }
    }
    func logout(refreshToken: String?) async { session = nil }
    func restoreSession(refreshToken: String) async throws -> AuthenticatedSession { try await refresh(refreshToken: refreshToken) }
    func currentUser() async throws -> AuthenticatedUser? { session?.user }
    func currentDevice() async throws -> AuthorizedDevice? { session?.device }
    func revokeCurrentDevice() async throws { session = nil; scenario = .deviceRevoked; throw AuthenticationError.deviceRevoked }
}
