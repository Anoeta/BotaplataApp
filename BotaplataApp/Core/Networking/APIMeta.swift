import Foundation

struct APIMeta: Codable, Equatable, Sendable {
    let requestID: String
    let serverTime: Date?
    init(requestID: String, serverTime: Date? = nil) { self.requestID = requestID; self.serverTime = serverTime }
    enum CodingKeys: String, CodingKey { case requestID = "request_id", serverTime = "server_time" }
}
