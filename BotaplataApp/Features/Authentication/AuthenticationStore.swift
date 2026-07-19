import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AuthenticationStore {
    enum LoginPhase: Equatable { case idle, loading, error(String) }
    enum TwoFactorPhase: Equatable { case entry, validating, error(String) }
    var loginPhase: LoginPhase = .idle
    var twoFactorPhase: TwoFactorPhase = .entry
    var challenge: TwoFactorChallenge?
    var isSubmitting: Bool { loginPhase == .loading }
    private var restoreTask: Task<Void, Never>?
    var didCompleteOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Self.onboardingCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.onboardingCompletedKey) }
    }
    private let repository: AuthenticationRepository
    private let tokenStore: TokenStoreProtocol
    let session: AuthenticationSession
    private let appState: AppState
    static let onboardingCompletedKey = "onboardingCompleted"
    init(repository: AuthenticationRepository, tokenStore: TokenStoreProtocol, appState: AppState) {
        self.repository = repository; self.tokenStore = tokenStore; self.appState = appState; self.session = AuthenticationSession(repository: repository, tokenStore: tokenStore)
    }
    func restore() async {
        guard restoreTask == nil else { BotaplataLog.auth.info("AuthenticationStore.restore skipped reason=singleFlight"); return }
        appState.transition(to: .restoring)
        BotaplataLog.auth.info("AuthenticationStore.restore reason=appLaunch")
        do { _ = try await tokenStore.installationID(); if try await session.restore() != nil { appState.transition(to: .authenticated) } else { appState.transition(to: .loggedOut) } }
        catch AuthenticationError.deviceRevoked { try? await session.purgeLocal(); appState.transition(to: .revoked) }
        catch AuthenticationError.offline { appState.transition(to: .loggedOut) }
        catch AuthenticationError.refreshRevoked { try? await session.purgeLocal(); appState.transition(to: .expired) }
        catch AuthenticationError.refreshReuseDetected { try? await session.purgeLocal(); appState.transition(to: .expired) }
        catch AuthenticationError.accessTokenExpired { try? await session.purgeLocal(); appState.transition(to: .expired) }
        catch { appState.transition(to: .loggedOut) }
    }
    func login(username: String, password: String) async {
        guard loginPhase != .loading else { BotaplataLog.auth.info("AuthenticationStore.login skipped reason=singleFlight"); return }
        BotaplataLog.auth.info("AuthenticationStore.login reason=manualSubmit")
        loginPhase = .loading; appState.transition(to: .authenticating)
        let signpost = BotaplataSignpost.begin("login")
        do { let installation = try await tokenStore.installationID(); let device = DeviceFingerprint(installationID: installation, name: "iPhone", model: "iPhone", osVersion: ProcessInfo.processInfo.operatingSystemVersionString, appVersion: "1.0", locale: Locale.current.identifier); challenge = try await repository.login(username: username, password: password, device: device); BotaplataSignpost.end("login", id: signpost); loginPhase = .idle; appState.transition(to: .awaitingTwoFactor) }
        catch { BotaplataSignpost.end("login", id: signpost); let auth = (error as? AuthenticationError) ?? .unknown; loginPhase = .error(auth.authDisplayMessage); appState.transition(to: .loggedOut) }
    }
    func verify(code: String) async {
        guard let challenge else { return }
        twoFactorPhase = .validating
        let signpost = BotaplataSignpost.begin("2FA validation")
        do { let s = try await repository.verifyTwoFactor(challengeID: challenge.id, code: code); try await session.apply(s); BotaplataSignpost.end("2FA validation", id: signpost); self.challenge = nil; twoFactorPhase = .entry; appState.transition(to: .authenticated) }
        catch { BotaplataSignpost.end("2FA validation", id: signpost); let auth = (error as? AuthenticationError) ?? .unknown; twoFactorPhase = .error(auth.authDisplayMessage); if auth == .deviceRevoked { appState.transition(to: .revoked) } else if auth == .challengeExpired { appState.transition(to: .expired) } }
    }
    func logout() async { await session.logout(); challenge = nil; appState.transition(to: .loggedOut) }
    func lockLocally() { appState.transition(to: .lockedLocally) }
    func unlockLocally() { appState.transition(to: .authenticated) }
}


extension AuthenticationError {
    var authDisplayMessage: String {
        switch self {
        case .notConfigured:
            "Serveur non configuré\n\nAjoutez l’adresse du serveur Botaplata dans la configuration de l’app."
        case .offline:
            "Accès au réseau local bloqué\n\nAutorisez Botaplata dans Réglages > Confidentialité et sécurité > Réseau local."
        case .serverUnavailable, .maintenance:
            "Serveur indisponible\n\nL’iPhone ne parvient pas à joindre Botaplata pour le moment."
        case .invalidCredentials:
            "Identifiants incorrects\n\nVérifiez votre email et votre mot de passe."
        case .invalidTwoFactorCode:
            "Code incorrect\n\nVérifiez le code à 6 chiffres puis réessayez."
        case .accessTokenExpired, .refreshRevoked, .refreshReuseDetected, .challengeExpired:
            "Session expirée\n\nReconnectez-vous pour continuer."
        default:
            userMessage
        }
    }
}

extension AuthenticationStore {
    static func preview(
        loginPhase: LoginPhase = .idle,
        twoFactorPhase: TwoFactorPhase = .entry,
        challenge: TwoFactorChallenge? = nil
    ) -> AuthenticationStore {
        let state = AppState(sessionState: .loggedOut, environment: .debugPreview)
        let store = AuthenticationStore(repository: MockAuthenticationRepository(), tokenStore: InMemoryTokenStore(), appState: state)
        store.loginPhase = loginPhase
        store.twoFactorPhase = twoFactorPhase
        store.challenge = challenge
        return store
    }
}
