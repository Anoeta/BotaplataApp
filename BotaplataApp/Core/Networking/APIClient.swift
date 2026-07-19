import Foundation
import OSLog
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
    init(baseURL: URL, session: URLSession = .shared, timeout: TimeInterval = 15) { self.baseURL = baseURL; self.session = session; self.timeout = timeout }


    func request<Response: Decodable & Sendable>(_ endpoint: APIEndpoint) async throws -> Response {
        try await request(endpoint, encodedBody: nil)
    }

    private func request<Response: Decodable & Sendable>(_ endpoint: APIEndpoint, encodedBody: Data?) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)
        if !endpoint.queryItems.isEmpty { components?.queryItems = endpoint.queryItems }
        guard let url = components?.url else { throw APIClientError.invalidURL }
        let effectiveTimeout = min(timeout, APIEndpointTimeoutPolicy.timeout(for: endpoint.path))
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: effectiveTimeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let encodedBody {
            request.httpBody = encodedBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let requestID = String(UUID().uuidString.prefix(8))
        let feature = Self.feature(for: endpoint.path)
        let sanitizedPath = Self.sanitizedEndpoint(path: endpoint.path, queryItems: endpoint.queryItems)
        let startedAt = Date()
        BotaplataLog.network.info("[\(requestID, privacy: .public)] REQUEST START\n\(endpoint.method.rawValue, privacy: .public)\n\(url.absoluteString, privacy: .public) path=\(sanitizedPath, privacy: .public) feature=\(feature, privacy: .public) timeout=\(effectiveTimeout, privacy: .public)s auth=\(endpoint.headers["Authorization"] == nil ? "none" : "bearer", privacy: .public)")
        let requestSignpost = BotaplataSignpost.begin("network request")
        do {
            let networkStartedAt = Date()
            let (data, response) = try await session.data(for: request)
            let networkDuration = Date().timeIntervalSince(networkStartedAt)
            guard let http = response as? HTTPURLResponse else { throw APIClientError.network }
            BotaplataLog.network.info("[\(requestID, privacy: .public)] RESPONSE HEADERS status=\(http.statusCode, privacy: .public) bytes=\(data.count, privacy: .public) network=\(networkDuration, privacy: .public)s")
            if !(200..<300).contains(http.statusCode) {
                if let envelope = try? JSONCoding.decoder.decode(APIEnvelope<EmptyResponse>.self, from: data), let payload = envelope.error { throw APIClientError.backend(statusCode: http.statusCode, error: payload, requestID: envelope.meta.requestID) }
                throw APIClientError.httpStatus(http.statusCode, requestID: nil)
            }
            let decodingStartedAt = Date()
            BotaplataLog.network.debug("[\(requestID, privacy: .public)] DECODING START dto=\(String(describing: Response.self), privacy: .public)")
            let decodeSignpost = BotaplataSignpost.begin("JSON decoding")
            let decoded: Response
            do {
                decoded = try JSONCoding.decoder.decode(Response.self, from: data)
            } catch let decodingError as DecodingError {
                BotaplataSignpost.end("JSON decoding", id: decodeSignpost)
                Self.logDecodingError(decodingError, data: data, requestID: requestID, endpoint: sanitizedPath, dto: String(describing: Response.self))
                throw decodingError
            }
            BotaplataSignpost.end("JSON decoding", id: decodeSignpost)
            let decodingDuration = Date().timeIntervalSince(decodingStartedAt)
            BotaplataLog.network.debug("[\(requestID, privacy: .public)] DECODING SUCCESS dto=\(String(describing: Response.self), privacy: .public) duration=\(decodingDuration, privacy: .public)s")
            let total = Date().timeIntervalSince(startedAt)
            BotaplataLog.network.info("[\(requestID, privacy: .public)] REQUEST END completed total=\(total, privacy: .public)s cache=miss authReplay=false retry=false")
            BotaplataSignpost.end("network request", id: requestSignpost)
            await NetworkDiagnosticsStore.shared.record(NetworkDiagnosticEntry(requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, duration: total, statusCode: http.statusCode, result: .success, cacheStatus: .miss))
            return decoded
        } catch is CancellationError { BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.cancelled }
        catch let error as APIClientError { await Self.recordFailure(error, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw error }
        catch is DecodingError { await Self.recordFailure(APIClientError.decoding, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.decoding }
        catch let error as URLError where error.code == .timedOut { await Self.recordFailure(APIClientError.timeout, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.timeout }
        catch let error as URLError where error.code == .cannotConnectToHost || error.code == .notConnectedToInternet { await Self.recordFailure(APIClientError.network, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.network }
        catch { await Self.recordFailure(APIClientError.network, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.network }
    }

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
        let effectiveTimeout = min(timeout, APIEndpointTimeoutPolicy.timeout(for: endpoint.path))
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: effectiveTimeout)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let encodedBody {
            request.httpBody = encodedBody
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let requestID = String(UUID().uuidString.prefix(8))
        let feature = Self.feature(for: endpoint.path)
        let sanitizedPath = Self.sanitizedEndpoint(path: endpoint.path, queryItems: endpoint.queryItems)
        let startedAt = Date()
        BotaplataLog.network.info("[\(requestID, privacy: .public)] REQUEST START\n\(endpoint.method.rawValue, privacy: .public)\n\(url.absoluteString, privacy: .public) path=\(sanitizedPath, privacy: .public) feature=\(feature, privacy: .public) timeout=\(effectiveTimeout, privacy: .public)s auth=\(endpoint.headers["Authorization"] == nil ? "none" : "bearer", privacy: .public)")
        let requestSignpost = BotaplataSignpost.begin("network request")
        do {
            let networkStartedAt = Date()
            let (data, response) = try await session.data(for: request)
            let networkDuration = Date().timeIntervalSince(networkStartedAt)
            guard let http = response as? HTTPURLResponse else { throw APIClientError.network }
            BotaplataLog.network.info("[\(requestID, privacy: .public)] RESPONSE HEADERS status=\(http.statusCode, privacy: .public) bytes=\(data.count, privacy: .public) network=\(networkDuration, privacy: .public)s")
            let decodingStartedAt = Date()
            BotaplataLog.network.debug("[\(requestID, privacy: .public)] DECODING START dto=\(String(describing: Response.self), privacy: .public)")
            let decodeSignpost = BotaplataSignpost.begin("JSON decoding")
            let envelope: APIEnvelope<Response>
            do {
                envelope = try JSONCoding.decoder.decode(APIEnvelope<Response>.self, from: data)
            } catch let decodingError as DecodingError {
                BotaplataSignpost.end("JSON decoding", id: decodeSignpost)
                Self.logDecodingError(decodingError, data: data, requestID: requestID, endpoint: sanitizedPath, dto: String(describing: Response.self))
                throw decodingError
            }
            BotaplataSignpost.end("JSON decoding", id: decodeSignpost)
            let decodingDuration = Date().timeIntervalSince(decodingStartedAt)
            BotaplataLog.network.debug("[\(requestID, privacy: .public)] DECODING SUCCESS dto=\(String(describing: Response.self), privacy: .public) duration=\(decodingDuration, privacy: .public)s")
            guard envelope.version == "mobile_v1" else { throw APIClientError.invalidVersion(envelope.version) }
            if envelope.ok, (200..<300).contains(http.statusCode) {
                let total = Date().timeIntervalSince(startedAt)
                BotaplataLog.network.info("[\(requestID, privacy: .public)] REQUEST END completed total=\(total, privacy: .public)s cache=miss authReplay=false retry=false")
                BotaplataSignpost.end("network request", id: requestSignpost)
                await NetworkDiagnosticsStore.shared.record(NetworkDiagnosticEntry(requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, duration: total, statusCode: http.statusCode, result: .success, cacheStatus: .miss))
                return envelope
            }
            let mapped = AuthenticationError(code: envelope.error?.code)
            if !(200..<300).contains(http.statusCode) {
                if let payload = envelope.error { throw APIClientError.backend(statusCode: http.statusCode, error: payload, requestID: envelope.meta.requestID) }
                throw APIClientError.httpStatus(http.statusCode, requestID: envelope.meta.requestID)
            }
            throw APIClientError.business(mapped, requestID: envelope.meta.requestID)
        } catch is CancellationError { BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.cancelled }
        catch let error as APIClientError { await Self.recordFailure(error, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw error }
        catch is DecodingError { await Self.recordFailure(APIClientError.decoding, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.decoding }
        catch let error as URLError where error.code == .timedOut { await Self.recordFailure(APIClientError.timeout, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.timeout }
        catch let error as URLError where error.code == .cannotConnectToHost || error.code == .notConnectedToInternet { await Self.recordFailure(APIClientError.network, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.network }
        catch { await Self.recordFailure(APIClientError.network, requestID: requestID, method: endpoint.method.rawValue, endpoint: sanitizedPath, feature: feature, startedAt: startedAt, statusCode: nil); BotaplataSignpost.end("network request", id: requestSignpost); throw APIClientError.network }
    }

    private static func sanitizedEndpoint(path: String, queryItems: [URLQueryItem]) -> String {
        guard !queryItems.isEmpty else { return path.hasPrefix("/") ? path : "/" + path }
        let safe = queryItems.map { "\($0.name)=<redacted>" }.joined(separator: "&")
        return (path.hasPrefix("/") ? path : "/" + path) + "?" + safe
    }

    private static func feature(for path: String) -> String {
        if path.contains("/auth/") { return "Auth" }
        if path.contains("/active") { return "Dashboard" }
        if path.contains("/real/sessions") { return "Sessions" }
        if path.contains("/health") { return "Diagnostics" }
        return "Network"
    }

    private static func recordFailure(_ error: APIClientError, requestID: String, method: String, endpoint: String, feature: String, startedAt: Date, statusCode: Int?) async {
        let total = Date().timeIntervalSince(startedAt)
        let category = error.resultCategory
        BotaplataLog.network.error("[\(requestID, privacy: .public)] failed category=\(category.rawValue, privacy: .public) total=\(total, privacy: .public)s")
        await NetworkDiagnosticsStore.shared.record(NetworkDiagnosticEntry(requestID: requestID, method: method, endpoint: endpoint, feature: feature, startedAt: startedAt, duration: total, statusCode: statusCode, result: category, cacheStatus: .miss))
    }

    private static func logDecodingError(_ error: DecodingError, data: Data, requestID: String, endpoint: String, dto: String) {
        guard DiagnosticsConfiguration.verboseNetworkLogs else { return }
        let path: String; let kind: String
        switch error {
        case .typeMismatch(let type, let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); kind = "typeMismatch expected=\(type)"
        case .keyNotFound(let key, let context): path = (context.codingPath + [key]).map(\.stringValue).joined(separator: "."); kind = "keyNotFound"
        case .valueNotFound(let type, let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); kind = "valueNotFound expected=\(type)"
        case .dataCorrupted(let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); kind = "dataCorrupted"
        @unknown default: path = "<unknown>"; kind = "unknown"
        }
        let diagnostics = Self.decodingDiagnostics(data: data, codingPath: path)
        BotaplataLog.network.error("[\(requestID, privacy: .public)] decoding failed endpoint=\(endpoint, privacy: .public) dto=\(dto, privacy: .public) path=\(path, privacy: .public) kind=\(kind, privacy: .public) \(diagnostics, privacy: .public)")
    }
    private static func decodingDiagnostics(data: Data, codingPath: String) -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return "actualType=unknown" }
        let parts = codingPath.split(separator: ".").map(String.init)
        let value = parts.reduce(Optional(root as Any)) { current, part in
            guard let current else { return nil }
            if let dict = current as? [String: Any] { return dict[part] }
            if let array = current as? [Any], let index = Int(part), array.indices.contains(index) { return array[index] }
            return nil
        }
        if let dict = value as? [String: Any] { return "actualType=object availableKeys=\(dict.keys.sorted())" }
        if value is [Any] { return "actualType=array" }
        if value is String { return "actualType=string" }
        if value is NSNumber { return "actualType=number" }
        if value is NSNull || value == nil { return "actualType=null" }
        return "actualType=unknown"
    }

}

enum HTTPHeaders {
    static func bearer(_ token: String) -> [String: String] { ["Authorization": "Bearer \(token)"] }
}

extension APIClientError {
    var resultCategory: ResultCategory {
        switch self {
        case .timeout: .timeout
        case .decoding, .invalidVersion: .decoding
        case .httpStatus, .backend, .business: .http
        case .cancelled: .cancelled
        case .network: .network
        default: .unknown
        }
    }
}
