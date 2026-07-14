import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationStore {
    enum LoginPhase: Equatable { case idle, loading, error(String) }
    enum TwoFactorPhase: Equatable { case entry, validating, error(String) }
    var loginPhase: LoginPhase = .idle
    var twoFactorPhase: TwoFactorPhase = .entry
    var challenge: TwoFactorChallenge?
    var didCompleteOnboarding = false
    private let repository: AuthenticationRepository
    private let tokenStore: TokenStoreProtocol
    private let session: AuthenticationSession
    private let appState: AppState
    init(repository: AuthenticationRepository, tokenStore: TokenStoreProtocol, appState: AppState) {
        self.repository = repository; self.tokenStore = tokenStore; self.appState = appState; self.session = AuthenticationSession(repository: repository, tokenStore: tokenStore)
    }
    func restore() async {
        appState.transition(to: .restoring)
        do { _ = try await tokenStore.installationID(); if try await session.restore() != nil { appState.transition(to: .authenticated) } else { appState.transition(to: .loggedOut) } }
        catch AuthenticationError.deviceRevoked { try? await session.purgeLocal(); appState.transition(to: .revoked) }
        catch AuthenticationError.offline { appState.transition(to: .loggedOut) }
        catch AuthenticationError.refreshRevoked { try? await session.purgeLocal(); appState.transition(to: .expired) }
        catch AuthenticationError.refreshReuseDetected { try? await session.purgeLocal(); appState.transition(to: .expired) }
        catch AuthenticationError.accessTokenExpired { try? await session.purgeLocal(); appState.transition(to: .expired) }
        catch { appState.transition(to: .loggedOut) }
    }
    func login(username: String, password: String) async {
        guard loginPhase != .loading else { return }
        loginPhase = .loading; appState.transition(to: .authenticating)
        do { let installation = try await tokenStore.installationID(); let device = DeviceFingerprint(installationID: installation, name: "iPhone", model: "iPhone", osVersion: ProcessInfo.processInfo.operatingSystemVersionString, appVersion: "1.0", locale: Locale.current.identifier); challenge = try await repository.login(username: username, password: password, device: device); loginPhase = .idle; appState.transition(to: .awaitingTwoFactor) }
        catch { let message = (error as? AuthenticationError)?.userMessage ?? AuthenticationError.unknown.userMessage; loginPhase = .error(message); appState.transition(to: .loggedOut) }
    }
    func verify(code: String) async {
        guard let challenge else { return }
        twoFactorPhase = .validating
        do { let s = try await repository.verifyTwoFactor(challengeID: challenge.id, code: code); try await session.apply(s); self.challenge = nil; twoFactorPhase = .entry; appState.transition(to: .authenticated) }
        catch { let auth = (error as? AuthenticationError) ?? .unknown; twoFactorPhase = .error(auth.userMessage); if auth == .deviceRevoked { appState.transition(to: .revoked) } else if auth == .challengeExpired { appState.transition(to: .expired) } }
    }
    func logout() async { await session.logout(); challenge = nil; appState.transition(to: .loggedOut) }
    func lockLocally() { appState.transition(to: .lockedLocally) }
    func unlockLocally() { appState.transition(to: .authenticated) }
}
