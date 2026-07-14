import Foundation

struct AuthorizedDevice: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let model: String
    let osVersion: String
    let appVersion: String
    let locale: String
    let createdAt: Date
    let lastSeenAt: Date?
    let lastAuthenticatedAt: Date?
    let isCurrent: Bool
    let isRevoked: Bool
    enum CodingKeys: String, CodingKey { case id, name, model, osVersion = "os_version", appVersion = "app_version", locale, createdAt = "created_at", lastSeenAt = "last_seen_at", lastAuthenticatedAt = "last_authenticated_at", isCurrent = "is_current", isRevoked = "is_revoked" }
}
