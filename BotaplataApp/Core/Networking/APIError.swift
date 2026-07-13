import Foundation

struct APIErrorPayload: Codable, Equatable, Sendable {
    let code: String
    let message: String
    let details: String?
    let retryable: Bool
}
