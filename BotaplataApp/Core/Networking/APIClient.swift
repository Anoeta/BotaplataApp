import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct EmptyResponse: Decodable, Sendable {}

enum APIClientError: Error, Sendable {
    case invalidURL, invalidVersion(String), httpStatus(Int, requestID: String?), backend(statusCode: Int, error: APIErrorPayload, requestID: String?), business(AuthenticationError, requestID: String?), decoding, network, cancelled, timeout
}

struct APIClient: APIClientProtocol {
    let baseURL: URL
    let session: URLSession
    let timeout: TimeInterval
    init(baseURL: URL, session: URLSession = .shared, timeout: TimeInterval = 20) { self.baseURL = baseURL; self.session = session; self.timeout = timeout }

    func send<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> Response {
        let envelope: APIEnvelope<Response> = try await sendEnvelope(endpoint)
        guard let payload = envelope.data else { throw APIClientError.decoding }
        return payload
    }

    func sendEnvelope<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> APIEnvelope<Response> {
        try await sendEnvelope(endpoint, encodedBody: nil)
    }

    func send<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body) async throws -> Response {
        let envelope: APIEnvelope<Response> = try await sendEnvelope(endpoint, body: body)
        guard let payload = envelope.data else { throw APIClientError.decoding }
        return payload
    }

    func sendEnvelope<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body) async throws -> APIEnvelope<Response> {
        let encodedBody = try JSONCoding.encoder.encode(body)
        return try await sendEnvelope(endpoint, encodedBody: encodedBody)
    }

    private func sendEnvelope<Response: Decodable & Sendable>(_ endpoint: APIEndpoint, encodedBody: Data?) async throws -> APIEnvelope<Response> {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty { components?.queryItems = endpoint.queryItems }
        guard let url = components?.url else { throw APIClientError.invalidURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let encodedBody {
            request.httpBody = encodedBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIClientError.network }
            let envelope = try JSONCoding.decoder.decode(APIEnvelope<Response>.self, from: data)
            guard envelope.version == "mobile_v1" else { throw APIClientError.invalidVersion(envelope.version) }
            if envelope.ok, (200..<300).contains(http.statusCode) { return envelope }
            let mapped = AuthenticationError(code: envelope.error?.code)
            if !(200..<300).contains(http.statusCode) {
                if let payload = envelope.error { throw APIClientError.backend(statusCode: http.statusCode, error: payload, requestID: envelope.meta.requestID) }
                throw APIClientError.httpStatus(http.statusCode, requestID: envelope.meta.requestID)
            }
            throw APIClientError.business(mapped, requestID: envelope.meta.requestID)
        } catch is CancellationError { throw APIClientError.cancelled }
        catch let error as APIClientError { throw error }
        catch is DecodingError { throw APIClientError.decoding }
        catch let error as URLError where error.code == .timedOut { throw APIClientError.timeout }
        catch { throw APIClientError.network }
    }
}

enum HTTPHeaders {
    static func bearer(_ token: String) -> [String: String] { ["Authorization": "Bearer \(token)"] }
}
