import Foundation

struct AuthorizedDevice: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let installationID: String
    let name: String
    let revokedAt: Date?
    enum CodingKeys: String, CodingKey { case id, installationID = "installation_id", name, revokedAt = "revoked_at" }
}
