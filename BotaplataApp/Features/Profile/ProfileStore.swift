import Foundation
import Observation

struct ProfileDiagnostic: Equatable, Sendable {
    let appVersion: String
    let build: String
    let environment: String
    let isBackendConfigured: Bool
    let authenticationState: String
    let biometricState: String
    var sanitizedText: String { "Botaplata \(appVersion) (\(build))\nEnvironnement : \(environment)\nSession : \(authenticationState)\nBackend : \(isBackendConfigured ? "configuré" : "non configuré")\nBiométrie : \(biometricState)" }
}

enum DevicesContent: Equatable {
    case idle, loading, loaded([AuthorizedDevice]), refreshing([AuthorizedDevice]), offline([AuthorizedDevice], String), failed(String)
    var devices: [AuthorizedDevice] { switch self { case .loaded(let d), .refreshing(let d), .offline(let d, _): d; default: [] } }
}

@MainActor
@Observable
final class ProfileStore {
    var user: AuthenticatedUser?
    var devicesContent: DevicesContent = .idle
    var biometricAvailability: BiometricAvailability = .unavailable
    var biometricLockEnabled = false
    var message: String?
    private let authSession: AuthenticationSession
    private let appState: AppState
    private let authenticator: BiometricAuthenticating
    private let preferences: SecurityPreferencesStore
    private let bundle: Bundle
    private var loadTask: Task<Void, Never>?
    private var revocationTasks: [String: Task<Void, Never>] = [:]

    init(authSession: AuthenticationSession, appState: AppState, authenticator: BiometricAuthenticating, preferences: SecurityPreferencesStore, bundle: Bundle = .main) {
        self.authSession = authSession; self.appState = appState; self.authenticator = authenticator; self.preferences = preferences; self.bundle = bundle
    }

    var activeDevices: [AuthorizedDevice] { devicesContent.devices.filter { !$0.isRevoked } }
    var currentDevice: AuthorizedDevice? { activeDevices.first { $0.isCurrent } }
    var otherDevices: [AuthorizedDevice] { activeDevices.filter { !$0.isCurrent } }
    var accessSummary: String { (user?.permissions.contains { $0.localizedCaseInsensitiveContains("read") } == true) ? "Lecture seule" : "Accès mobile" }
    var diagnostic: ProfileDiagnostic { ProfileDiagnostic(appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Inconnue", build: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Inconnu", environment: appState.environment.name, isBackendConfigured: appState.environment.baseURL != nil, authenticationState: authStateText, biometricState: biometricText) }
    var biometricText: String { biometricAvailability == .available ? (biometricLockEnabled ? "Activé" : "Désactivé") : "Indisponible" }
    private var authStateText: String { switch appState.sessionState { case .authenticated, .refreshing, .offlineWithCachedSession: "authentifiée"; case .lockedLocally: "verrouillée localement"; case .revoked: "révoquée"; case .expired: "expirée"; default: "non authentifiée" } }

    func bootstrap() async { user = await authSession.user; biometricAvailability = await authenticator.availability(); biometricLockEnabled = await preferences.biometricLockEnabled(); await refreshDevices() }
    func refreshDevices() async { if let loadTask { await loadTask.value; return }; let previous = activeDevices; devicesContent = previous.isEmpty ? .loading : .refreshing(previous); let task = Task { [weak self] in await self?.performRefresh(previous: previous) }; loadTask = task; await task.value; loadTask = nil }
    private func performRefresh(previous: [AuthorizedDevice]) async {
        do { devicesContent = .loaded(try await authSession.authorizedDevices().filter { !$0.isRevoked }); user = await authSession.user }
        catch AuthenticationError.offline { devicesContent = previous.isEmpty ? .failed("Impossible de charger les appareils. Vérifiez votre connexion puis réessayez.") : .offline(previous, "Connexion momentanément indisponible. Dernier état connu affiché.") }
        catch AuthenticationError.deviceRevoked { appState.markRevoked(); purge() }
        catch AuthenticationError.accessTokenExpired, AuthenticationError.refreshRevoked, AuthenticationError.refreshReuseDetected { appState.markExpired(); purge() }
        catch { devicesContent = previous.isEmpty ? .failed("Impossible de charger les appareils. Vérifiez votre connexion puis réessayez.") : .offline(previous, "Connexion momentanément indisponible. Dernier état connu affiché.") }
    }
    func setBiometricLockEnabled(_ enabled: Bool) async {
        if !enabled { await preferences.setBiometricLockEnabled(false); biometricLockEnabled = false; return }
        biometricAvailability = await authenticator.availability(); guard biometricAvailability == .available else { biometricLockEnabled = false; message = "La biométrie n'est pas disponible sur cet appareil."; return }
        let result = await authenticator.authenticate(reason: "Activer le verrouillage local de Botaplata")
        guard result == .succeeded else { biometricLockEnabled = false; message = result == .cancelled ? nil : "Le verrouillage biométrique n'a pas été activé."; return }
        await preferences.setBiometricLockEnabled(true); biometricLockEnabled = true; message = "Verrouillage biométrique activé."
    }
    func revoke(_ device: AuthorizedDevice) async { if let task = revocationTasks[device.id] { await task.value; return }; let task = Task { [weak self] in await self?.performRevoke(device) }; revocationTasks[device.id] = task; await task.value; revocationTasks[device.id] = nil }
    private func performRevoke(_ device: AuthorizedDevice) async {
        do { let result = try await authSession.revokeDevice(id: device.id); if result.currentDeviceRevoked { appState.markRevoked(); purge() } else { devicesContent = .loaded(activeDevices.filter { $0.id != result.revokedDeviceID }); message = "Accès révoqué." } }
        catch AuthenticationError.offline { message = "Connexion momentanément indisponible. Réessayez plus tard." }
        catch AuthenticationError.deviceRevoked { appState.markRevoked(); purge() }
        catch AuthenticationError.accessTokenExpired, AuthenticationError.refreshRevoked, AuthenticationError.refreshReuseDetected { appState.markExpired(); purge() }
        catch { message = "La révocation a échoué. Réessayez." }
    }
    func purge() { user = nil; devicesContent = .idle; message = nil }
}

struct LocalBiometricLockCoordinator: Sendable {
    func shouldLock(afterBackground: Bool, biometricEnabled: Bool, state: AppSessionState) -> Bool { afterBackground && biometricEnabled && state == .authenticated }
}

#if DEBUG
struct PreviewBiometricAuthenticator: BiometricAuthenticating {
    var availabilityValue: BiometricAvailability = .available
    var result: BiometricResult = .succeeded
    func availability() async -> BiometricAvailability { availabilityValue }
    func authenticate(reason: String) async -> BiometricResult { result }
}

actor InMemorySecurityPreferencesStore: SecurityPreferencesStore {
    private var enabled: Bool
    init(enabled: Bool = false) { self.enabled = enabled }
    func biometricLockEnabled() async -> Bool { enabled }
    func setBiometricLockEnabled(_ enabled: Bool) async { self.enabled = enabled }
}

extension ProfileStore {
    static func preview(biometricEnabled: Bool = false, availability: BiometricAvailability = .available) -> ProfileStore {
        let state = AppState.demo()
        let repo = MockAuthenticationRepository()
        let token = InMemoryTokenStore()
        let session = AuthenticationSession(repository: repo, tokenStore: token)
        let store = ProfileStore(authSession: session, appState: state, authenticator: PreviewBiometricAuthenticator(availabilityValue: availability), preferences: InMemorySecurityPreferencesStore(enabled: biometricEnabled))
        Task { try? await session.apply(AuthenticationFixtures.successfulSession); await store.bootstrap() }
        return store
    }
}
#endif
