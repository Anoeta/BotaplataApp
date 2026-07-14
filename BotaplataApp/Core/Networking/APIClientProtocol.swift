import Foundation

protocol APIClientProtocol: Sendable {
    func send<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body?) async throws -> Response
    func sendEnvelope<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body?) async throws -> APIEnvelope<Response>
}

extension APIClientProtocol {
    func sendEnvelope<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body?) async throws -> APIEnvelope<Response> { throw APIClientError.network }
}
