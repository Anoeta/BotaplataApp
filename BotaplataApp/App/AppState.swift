import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var sessionState: AppSessionState
    let environment: AppEnvironment

    init(sessionState: AppSessionState = .unknown, environment: AppEnvironment = .debugPreview) {
        self.sessionState = sessionState
        self.environment = environment
    }

    static func demo() -> AppState { AppState(sessionState: .authenticated, environment: .debugPreview) }

    @discardableResult
    func transition(to newState: AppSessionState) -> Bool {
        guard sessionState.canTransition(to: newState) || sessionState == newState else { return false }
        sessionState = newState
        return true
    }

    func restore() { _ = transition(to: .restoring) }
    func markLoggedOut() { _ = transition(to: .loggedOut) }
    func markAuthenticated() { _ = transition(to: .authenticated) }
    func markRevoked() { _ = transition(to: .revoked) }
    func markExpired() { _ = transition(to: .expired) }
}

enum AppSessionState: Equatable, Sendable {
    case unknown, restoring, loggedOut, authenticating, awaitingTwoFactor, authenticated, refreshing, lockedLocally, revoked, expired, offlineWithCachedSession

    func canTransition(to next: AppSessionState) -> Bool {
        switch (self, next) {
        case (.unknown, .restoring), (.restoring, .loggedOut), (.restoring, .authenticated), (.restoring, .offlineWithCachedSession), (.restoring, .expired), (.restoring, .revoked), (.loggedOut, .authenticating), (.authenticating, .awaitingTwoFactor), (.authenticating, .loggedOut), (.awaitingTwoFactor, .authenticated), (.awaitingTwoFactor, .loggedOut), (.awaitingTwoFactor, .expired), (.authenticated, .refreshing), (.authenticated, .lockedLocally), (.authenticated, .revoked), (.authenticated, .expired), (.authenticated, .loggedOut), (.refreshing, .authenticated), (.refreshing, .expired), (.refreshing, .revoked), (.refreshing, .offlineWithCachedSession), (.lockedLocally, .authenticated), (.lockedLocally, .loggedOut), (.revoked, .loggedOut), (.expired, .loggedOut), (.offlineWithCachedSession, .refreshing), (.offlineWithCachedSession, .loggedOut):
            return true
        default:
            return false
        }
    }
}
