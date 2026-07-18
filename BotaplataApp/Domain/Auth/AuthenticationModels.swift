import Foundation

enum AuthenticationError: Error, Equatable, Sendable {
    case invalidCredentials, twoFactorNotConfigured, invalidTwoFactorCode, challengeExpired, tooManyAttempts
    case accessTokenExpired, refreshRevoked, refreshReuseDetected, deviceRevoked, userDisabled, deviceLimitReached
    case permissionDenied, validationError, serverUnavailable, offline, rateLimited, maintenance
    case notConfigured, unknown

    var userMessage: String {
        switch self {
        case .invalidCredentials: "Identifiant ou mot de passe incorrect."
        case .invalidTwoFactorCode: "Ce code n'est pas valide. Vérifiez-le et réessayez."
        case .challengeExpired: "Cette vérification a expiré. Recommencez la connexion."
        case .tooManyAttempts: "Trop de tentatives ont été effectuées. Recommencez la connexion."
        case .twoFactorNotConfigured: "La double authentification doit être activée avant d’utiliser l’application mobile."
        case .accessTokenExpired: "Votre session a expiré."
        case .refreshRevoked: "Votre session n’est plus valide. Connectez-vous de nouveau."
        case .refreshReuseDetected: "Votre session a été fermée par sécurité. Connectez-vous de nouveau."
        case .deviceRevoked: "Cet iPhone n'est plus autorisé à accéder à Botaplata."
        case .userDisabled: "Ce compte n’est plus autorisé à accéder à Botaplata."
        case .deviceLimitReached: "Le nombre maximal d’appareils autorisés est atteint."
        case .serverUnavailable: "Le service est momentanément indisponible."
        case .offline: "Connexion indisponible. Mode hors ligne limité."
        case .rateLimited: "Trop de tentatives ont été effectuées. Réessayez plus tard."
        case .maintenance: "Botaplata est en maintenance."
        case .notConfigured: "L'authentification serveur n'est pas encore configurée."
        case .permissionDenied, .validationError, .unknown: "Une erreur est survenue. Réessayez."
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
    let deviceID: String
}

extension AuthenticatedSession {
    init(dto: AuthenticationTokensDTO) {
        self.init(
            accessToken: dto.accessToken,
            accessTokenExpiresAt: dto.accessTokenExpiresAt,
            refreshToken: dto.refreshToken,
            refreshTokenExpiresAt: dto.refreshTokenExpiresAt,
            tokenType: dto.tokenType,
            user: dto.user,
            deviceID: dto.deviceID
        )
    }
}

struct AuthenticationTokensDTO: Codable, Equatable, Sendable {
    let accessToken: String; let accessTokenExpiresAt: Date; let refreshToken: String; let refreshTokenExpiresAt: Date; let tokenType: String; let deviceID: String; let user: AuthenticatedUser
    enum CodingKeys: String, CodingKey { case accessToken = "access_token", accessTokenExpiresAt = "access_token_expires_at", refreshToken = "refresh_token", refreshTokenExpiresAt = "refresh_token_expires_at", tokenType = "token_type", deviceID = "device_id", user }
}


extension AuthenticationError {
    init(code: String?) {
        switch code {
        case "AUTH_INVALID_CREDENTIALS": self = .invalidCredentials
        case "AUTH_2FA_NOT_CONFIGURED": self = .twoFactorNotConfigured
        case "AUTH_2FA_INVALID": self = .invalidTwoFactorCode
        case "AUTH_CHALLENGE_EXPIRED": self = .challengeExpired
        case "AUTH_TOO_MANY_ATTEMPTS": self = .tooManyAttempts
        case "AUTH_TOKEN_EXPIRED": self = .accessTokenExpired
        case "AUTH_REFRESH_REVOKED": self = .refreshRevoked
        case "AUTH_REFRESH_REUSE_DETECTED": self = .refreshReuseDetected
        case "AUTH_DEVICE_REVOKED": self = .deviceRevoked
        case "AUTH_USER_DISABLED": self = .userDisabled
        case "AUTH_DEVICE_LIMIT_REACHED": self = .deviceLimitReached
        case "PERMISSION_DENIED": self = .permissionDenied
        case "RATE_LIMITED": self = .rateLimited
        case "SERVER_UNAVAILABLE": self = .serverUnavailable
        case "MAINTENANCE": self = .maintenance
        case "VALIDATION_ERROR": self = .validationError
        default: self = .unknown
        }
    }
}
