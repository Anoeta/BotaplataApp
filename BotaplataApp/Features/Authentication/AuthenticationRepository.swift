import Foundation

protocol AuthenticationRepository: Sendable {
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession
    func refresh(refreshToken: String) async throws -> AuthenticatedSession
    func logout(refreshToken: String?) async
    func restoreSession(refreshToken: String) async throws -> AuthenticatedSession
    func currentUser() async throws -> AuthenticatedUser?
    func currentDevice() async throws -> AuthorizedDevice?
    func revokeCurrentDevice() async throws
}

struct UnconfiguredAuthenticationRepository: AuthenticationRepository {
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge { throw AuthenticationError.notConfigured }
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession { throw AuthenticationError.notConfigured }
    func refresh(refreshToken: String) async throws -> AuthenticatedSession { throw AuthenticationError.notConfigured }
    func logout(refreshToken: String?) async {}
    func restoreSession(refreshToken: String) async throws -> AuthenticatedSession { throw AuthenticationError.notConfigured }
    func currentUser() async throws -> AuthenticatedUser? { nil }
    func currentDevice() async throws -> AuthorizedDevice? { nil }
    func revokeCurrentDevice() async throws { throw AuthenticationError.notConfigured }
}
