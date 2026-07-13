import Foundation

enum AuthenticationError: Error, Equatable, Sendable {
    case invalidCredentials, twoFactorRequired, invalidTwoFactorCode, challengeExpired, tooManyAttempts
    case accessTokenExpired, refreshRevoked, deviceRevoked, serverUnavailable, offline, rateLimited, maintenance
    case notConfigured, unknown

    var userMessage: String {
        switch self {
        case .invalidCredentials: "Identifiant ou mot de passe incorrect."
        case .invalidTwoFactorCode: "Ce code n'est pas valide. Vérifiez-le et réessayez."
        case .challengeExpired: "Cette vérification a expiré. Recommencez la connexion."
        case .tooManyAttempts: "Trop de tentatives. Recommencez la connexion."
        case .accessTokenExpired, .refreshRevoked: "Votre session a expiré."
        case .deviceRevoked: "Cet iPhone n'est plus autorisé à accéder à Botaplata."
        case .serverUnavailable: "Le service est momentanément indisponible."
        case .offline: "Connexion indisponible. Mode hors ligne limité."
        case .rateLimited: "Trop d'essais. Réessayez dans quelques instants."
        case .maintenance: "Botaplata est en maintenance."
        case .notConfigured: "L'authentification serveur n'est pas encore configurée."
        case .twoFactorRequired, .unknown: "Une erreur est survenue. Réessayez."
        }
    }
}

struct DeviceFingerprint: Codable, Equatable, Sendable {
    let installationID: String, name: String, model: String, osVersion: String, appVersion: String, locale: String
    enum CodingKeys: String, CodingKey { case installationID = "installation_id", name, model, osVersion = "os_version", appVersion = "app_version", locale }
}

struct LoginRequestDTO: Codable, Equatable, Sendable { let username: String; let password: String; let device: DeviceFingerprint }
struct TwoFactorVerifyRequestDTO: Codable, Equatable, Sendable { let challengeID: String; let code: String; enum CodingKeys: String, CodingKey { case challengeID = "challenge_id", code } }

struct AuthenticatedSession: Equatable, Sendable {
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
    let tokenType: String
    let user: AuthenticatedUser
    let device: AuthorizedDevice
}

struct AuthenticationTokensDTO: Codable, Equatable, Sendable {
    let accessToken: String; let accessTokenExpiresAt: Date; let refreshToken: String; let refreshTokenExpiresAt: Date; let tokenType: String; let deviceID: String; let user: AuthenticatedUser
    enum CodingKeys: String, CodingKey { case accessToken = "access_token", accessTokenExpiresAt = "access_token_expires_at", refreshToken = "refresh_token", refreshTokenExpiresAt = "refresh_token_expires_at", tokenType = "token_type", deviceID = "device_id", user }
}
