import Foundation

extension RealStrategyExplanationStore {
    convenience init(repository: RealStrategyExplanationRepository, authSession: AuthenticationSession, appState: AppState, ttl: TimeInterval = 30) {
        self.init(repository: repository, authorize: { work in
            try await authSession.withAccessTokenReplay(work)
        }, ttl: ttl, onAuthenticationFailure: { error in
            if error == .accessTokenExpired { appState.transition(to: .expired) }
            else if error == .deviceRevoked { appState.transition(to: .revoked) }
        })
    }
}
