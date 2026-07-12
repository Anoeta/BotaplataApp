import Foundation

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
    func restore() { sessionState = .restoring }
    func markLoggedOut() { sessionState = .loggedOut }
    func markAuthenticated() { sessionState = .authenticated }
    func markRevoked() { sessionState = .revoked }
    func markExpired() { sessionState = .expired }
}

enum AppSessionState: Equatable, Sendable {
    case unknown, restoring, loggedOut, authenticating, awaitingTwoFactor, authenticated, refreshing, lockedLocally, revoked, expired, offlineWithCachedSession
}
