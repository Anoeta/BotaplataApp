import Foundation

protocol RealSessionsRepository: Sendable {
    func fetchSessions(page: Int, pageSize: Int, accessToken: String) async throws -> RealSessionsPage
    func fetchSessionDetail(id: String, accessToken: String) async throws -> SessionDetail
}

struct RemoteRealSessionsRepository: RealSessionsRepository {
    let client: APIClientProtocol
    func fetchSessions(page: Int, pageSize: Int, accessToken: String) async throws -> RealSessionsPage {
        do {
            let endpoint = APIEndpoint(method: .get, path: "/api/mobile/v1/real/sessions", queryItems: [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "page_size", value: "\(pageSize)")], headers: HTTPHeaders.bearer(accessToken))
            let envelope: APIEnvelope<RealSessionsPageDTO> = try await client.sendEnvelope(endpoint, body: Optional<EmptyBody>.none)
            guard let dto = envelope.data else { throw AuthenticationError.serverUnavailable }
            return dto.mapped(warnings: envelope.warnings, serverTime: envelope.meta.serverTime)
        } catch APIClientError.business(let error, _) { throw error }
        catch APIClientError.backend(_, let payload, _) { throw AuthenticationError(code: payload.code) }
        catch APIClientError.httpStatus(401, _) { throw AuthenticationError.accessTokenExpired }
        catch APIClientError.network { throw AuthenticationError.offline }
        catch APIClientError.timeout { throw AuthenticationError.serverUnavailable }
        catch APIClientError.cancelled { throw CancellationError() }
        catch let error as AuthenticationError { throw error }
        catch { throw AuthenticationError.serverUnavailable }
    }
    func fetchSessionDetail(id: String, accessToken: String) async throws -> SessionDetail {
        do {
            let envelope: APIEnvelope<RealSessionDetailDTO> = try await client.sendEnvelope(APIEndpoint(method: .get, path: "/api/mobile/v1/real/sessions/\(id)", headers: HTTPHeaders.bearer(accessToken)), body: Optional<EmptyBody>.none)
            guard let dto = envelope.data else { throw AuthenticationError.serverUnavailable }
            return dto.mapped(warnings: envelope.warnings)
        } catch APIClientError.business(let error, _) { throw error }
        catch APIClientError.backend(_, let payload, _) { throw AuthenticationError(code: payload.code) }
        catch APIClientError.httpStatus(401, _) { throw AuthenticationError.accessTokenExpired }
        catch APIClientError.httpStatus(404, _) { throw AuthenticationError.validationError }
        catch APIClientError.network { throw AuthenticationError.offline }
        catch APIClientError.timeout { throw AuthenticationError.serverUnavailable }
        catch APIClientError.cancelled { throw CancellationError() }
        catch let error as AuthenticationError { throw error }
        catch { throw AuthenticationError.serverUnavailable }
    }
}
struct UnconfiguredRealSessionsRepository: RealSessionsRepository { func fetchSessions(page: Int, pageSize: Int, accessToken: String) async throws -> RealSessionsPage { throw AuthenticationError.notConfigured }; func fetchSessionDetail(id: String, accessToken: String) async throws -> SessionDetail { throw AuthenticationError.notConfigured } }
struct MockRealSessionsRepository: RealSessionsRepository { var items: [SessionSummary] = PreviewFixtures.sessionSummaries; var details: [String: SessionDetail] = [PreviewFixtures.krakenDetail.id: PreviewFixtures.krakenDetail, PreviewFixtures.waitingBuy.id: PreviewFixtures.waitingBuy]
    func fetchSessions(page: Int, pageSize: Int, accessToken: String) async throws -> RealSessionsPage { RealSessionsPage(items: items, pagination: RealSessionsPagination(page: page, pageSize: pageSize, total: items.count, hasMore: false), warnings: [], serverTime: PreviewFixtures.now) }
    func fetchSessionDetail(id: String, accessToken: String) async throws -> SessionDetail { details[id] ?? PreviewFixtures.detail(for: id) }
}
