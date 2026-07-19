import Foundation
import Observation
import OSLog

protocol RealStrategyExplanationRepository: Sendable { func fetchStrategyExplanation(sessionID: String, accessToken: String) async throws -> StrategyExplanation }
struct RemoteRealStrategyExplanationRepository: RealStrategyExplanationRepository { let client: APIClientProtocol
    func fetchStrategyExplanation(sessionID: String, accessToken: String) async throws -> StrategyExplanation {
        BotaplataLog.strategyExplanation.info("StrategyExplanationRepository.fetch session=\(sessionID, privacy: .public)")
        do { let dto: RealStrategyExplanationDTO = try await client.request(APIEndpoint(method: .get, path: "/api/mobile/v1/real/sessions/\(sessionID)/strategy-explanation", headers: HTTPHeaders.bearer(accessToken))); return dto.mapped() }
        catch APIClientError.business(let error, _) { throw error }
        catch APIClientError.backend(_, let payload, _) { throw AuthenticationError(code: payload.code) }
        catch APIClientError.httpStatus(401, _) { throw AuthenticationError.accessTokenExpired }
        catch APIClientError.httpStatus(404, _) { throw AuthenticationError.validationError }
        catch APIClientError.network { throw AuthenticationError.offline }
        catch APIClientError.timeout { throw AuthenticationError.serverUnavailable }
        catch APIClientError.decoding { throw AuthenticationError.contractIncompatible }
        catch APIClientError.invalidVersion { throw AuthenticationError.contractIncompatible }
        catch APIClientError.cancelled { throw CancellationError() }
        catch let error as AuthenticationError { throw error }
        catch { throw AuthenticationError.serverUnavailable }
    }
}
struct UnconfiguredRealStrategyExplanationRepository: RealStrategyExplanationRepository { func fetchStrategyExplanation(sessionID: String, accessToken: String) async throws -> StrategyExplanation { throw AuthenticationError.notConfigured } }
struct MockRealStrategyExplanationRepository: RealStrategyExplanationRepository { var explanation: StrategyExplanation = PreviewFixtures.strategyExplanationWait3; func fetchStrategyExplanation(sessionID: String, accessToken: String) async throws -> StrategyExplanation { explanation } }
