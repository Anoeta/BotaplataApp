import Foundation

struct APIMeta: Codable, Equatable, Sendable {
    let requestID: String
    enum CodingKeys: String, CodingKey { case requestID = "request_id" }
}
