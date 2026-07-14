import Foundation

enum AuthenticationFixtures {
    static let user = AuthenticatedUser(id: "fixture-user-demo", displayName: "Utilisateur démo", roles: [], permissions: [])
    static let device = AuthorizedDevice(id: "fixture-device-demo", name: "iPhone de démonstration", model: "iPhone", osVersion: "26.5", appVersion: "1.0", locale: "fr-FR", createdAt: Date(timeIntervalSince1970: 1_700_000_000), lastSeenAt: nil, lastAuthenticatedAt: nil, isCurrent: true, isRevoked: false)
    static var validChallenge: TwoFactorChallenge { TwoFactorChallenge(id: "fixture-challenge-valid", challengeType: "totp", expiresAt: Date().addingTimeInterval(300), attemptsRemaining: 5) }
    static var expiredChallenge: TwoFactorChallenge { TwoFactorChallenge(id: "fixture-challenge-expired", challengeType: "totp", expiresAt: Date().addingTimeInterval(-60), attemptsRemaining: 0) }
    static var successfulSession: AuthenticatedSession { AuthenticatedSession(accessToken: "fixture-access-token-never-production", accessTokenExpiresAt: Date().addingTimeInterval(900), refreshToken: "fixture-refresh-token-never-production", refreshTokenExpiresAt: Date().addingTimeInterval(86400 * 30), tokenType: "Bearer", user: user, deviceID: device.id) }
}
