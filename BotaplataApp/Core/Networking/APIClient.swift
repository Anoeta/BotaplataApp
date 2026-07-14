import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct EmptyBody: Encodable, Sendable {}
struct EmptyResponse: Codable, Sendable {}

enum APIClientError: Error, Sendable {
    case invalidURL, invalidVersion(String), httpStatus(Int, requestID: String?), business(AuthenticationError, requestID: String?), decoding, network, cancelled
}

struct APIClient: APIClientProtocol {
    let baseURL: URL
    let session: URLSession
    let timeout: TimeInterval
    init(baseURL: URL, session: URLSession = .shared, timeout: TimeInterval = 20) { self.baseURL = baseURL; self.session = session; self.timeout = timeout }

    func send<Response: Decodable & Sendable, Body: Encodable & Sendable>(_ endpoint: APIEndpoint, body: Body? = Optional<EmptyBody>.none) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty { components?.queryItems = endpoint.queryItems }
        guard let url = components?.url else { throw APIClientError.invalidURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let body { request.httpBody = try JSONCoding.encoder.encode(body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIClientError.network }
            let envelope = try JSONCoding.decoder.decode(APIEnvelope<Response>.self, from: data)
            guard envelope.version == "mobile_v1" else { throw APIClientError.invalidVersion(envelope.version) }
            if envelope.ok, (200..<300).contains(http.statusCode), let payload = envelope.data { return payload }
            let mapped = AuthenticationError(code: envelope.error?.code)
            if !(200..<300).contains(http.statusCode) { throw APIClientError.httpStatus(http.statusCode, requestID: envelope.meta.requestID) }
            throw APIClientError.business(mapped, requestID: envelope.meta.requestID)
        } catch is CancellationError { throw APIClientError.cancelled }
        catch let error as APIClientError { throw error }
        catch is DecodingError { throw APIClientError.decoding }
        catch { throw APIClientError.network }
    }
}

enum HTTPHeaders {
    static func bearer(_ token: String) -> [String: String] { ["Authorization": "Bearer \(token)"] }
}
