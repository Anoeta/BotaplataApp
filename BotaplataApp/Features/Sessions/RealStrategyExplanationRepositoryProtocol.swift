import Foundation

protocol RealStrategyExplanationRepository: Sendable {
    func fetchStrategyExplanation(sessionID: String, accessToken: String) async throws -> StrategyExplanation
}
