import Foundation

protocol APIClientProtocol: Sendable {
    func request<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> Response
    func send<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> Response
    func sendEnvelope<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> APIEnvelope<Response>
    func send<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body) async throws -> Response
    func sendEnvelope<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body) async throws -> APIEnvelope<Response>
}
