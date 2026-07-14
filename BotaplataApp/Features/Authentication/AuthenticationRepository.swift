import Foundation

protocol AuthenticationRepository: Sendable {
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession
    func refresh(refreshToken: String, installationID: String) async throws -> AuthenticatedSession
    func logout(accessToken: String?) async
    func authorizedDevices(accessToken: String) async throws -> [AuthorizedDevice]
    func revokeDevice(id: String, accessToken: String) async throws -> DeviceRevocationResult
}

struct UnconfiguredAuthenticationRepository: AuthenticationRepository {
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge { throw AuthenticationError.notConfigured }
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession { throw AuthenticationError.notConfigured }
    func refresh(refreshToken: String, installationID: String) async throws -> AuthenticatedSession { throw AuthenticationError.notConfigured }
    func logout(accessToken: String?) async {}
    func authorizedDevices(accessToken: String) async throws -> [AuthorizedDevice] { throw AuthenticationError.notConfigured }
    func revokeDevice(id: String, accessToken: String) async throws -> DeviceRevocationResult { throw AuthenticationError.notConfigured }
}
