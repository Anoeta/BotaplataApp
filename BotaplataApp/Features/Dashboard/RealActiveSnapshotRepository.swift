import Foundation

protocol RealActiveSnapshotRepository: Sendable { func fetchActiveSnapshot(accessToken: String) async throws -> RealActiveSnapshot }

struct RemoteRealActiveSnapshotRepository: RealActiveSnapshotRepository {
    let client: APIClientProtocol
    func fetchActiveSnapshot(accessToken: String) async throws -> RealActiveSnapshot {
        do {
            let envelope: APIEnvelope<RealActiveSnapshotDTO> = try await client.sendEnvelope(APIEndpoint(method: .get, path: "/api/mobile/v1/real/sessions/active-snapshot", headers: HTTPHeaders.bearer(accessToken)), body: Optional<EmptyBody>.none)
            guard let dto = envelope.data else { throw AuthenticationError.serverUnavailable }
            return dto.mapped(warnings: envelope.warnings, requestID: envelope.meta.requestID, serverTime: envelope.meta.serverTime)
        } catch APIClientError.business(let error, _) { throw error }
        catch APIClientError.backend(_, let payload, _) { throw AuthenticationError(code: payload.code) }
        catch APIClientError.httpStatus(401, _) { throw AuthenticationError.accessTokenExpired }
        catch APIClientError.network { throw AuthenticationError.offline }
        catch APIClientError.timeout { throw AuthenticationError.serverUnavailable }
        catch APIClientError.cancelled { throw CancellationError() }
        catch let error as AuthenticationError { throw error }
        catch { throw AuthenticationError.serverUnavailable }
    }
}

struct UnconfiguredRealActiveSnapshotRepository: RealActiveSnapshotRepository {
    func fetchActiveSnapshot(accessToken: String) async throws -> RealActiveSnapshot { throw AuthenticationError.notConfigured }
}

struct MockRealActiveSnapshotRepository: RealActiveSnapshotRepository {
    var snapshot: RealActiveSnapshot = RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.krakenDetail, warnings: [], requestID: "preview", serverTime: PreviewFixtures.now)
    func fetchActiveSnapshot(accessToken: String) async throws -> RealActiveSnapshot { snapshot }
}
