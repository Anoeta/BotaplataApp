import Foundation

struct AuthenticatedUser: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let roles: [String]
    let permissions: [String]
    enum CodingKeys: String, CodingKey { case id, displayName = "display_name", roles, permissions }
}
