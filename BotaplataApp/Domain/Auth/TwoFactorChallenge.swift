import Foundation

struct TwoFactorChallenge: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let challengeType: String
    let expiresAt: Date
    let attemptsRemaining: Int?
    enum CodingKeys: String, CodingKey { case id = "challenge_id", challengeType = "challenge_type", expiresAt = "expires_at", attemptsRemaining = "attempts_remaining" }
    var isExpired: Bool { Date() >= expiresAt }
}
