import Foundation

protocol APIClientProtocol: Sendable {
    func send<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body?) async throws -> Response
}
