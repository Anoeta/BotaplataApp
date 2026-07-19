import Foundation
import Observation

struct ProfileDiagnostic: Equatable, Sendable {
    let appVersion: String
    let build: String
    let environment: String
    let isBackendConfigured: Bool
    let authenticationState: String
    let biometricState: String
    let serverURL: String
    var sanitizedText: String { "Botaplata \(appVersion) (\(build))\nEnvironnement : \(environment)\nSession : \(authenticationState)\nBackend : \(isBackendConfigured ? "configuré" : "non configuré")\nURL serveur : \(serverURL)\nBiométrie : \(biometricState)" }
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
    var diagnostic: ProfileDiagnostic { ProfileDiagnostic(appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Inconnue", build: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "Inconnu", environment: appState.environment.name, isBackendConfigured: appState.environment.baseURL != nil, authenticationState: authStateText, biometricState: biometricText, serverURL: appState.environment.baseURL?.absoluteString ?? "non configurée") }
    var biometricText: String { biometricAvailability == .available ? (biometricLockEnabled ? "Activé" : "Désactivé") : "Indisponible" }
    private var authStateText: String { switch appState.sessionState { case .authenticated, .refreshing, .offlineWithCachedSession: "authentifiée"; case .lockedLocally: "verrouillée localement"; case .revoked: "révoquée"; case .expired: "expirée"; default: "non authentifiée" } }

    func bootstrap() async { user = await authSession.user; biometricAvailability = await authenticator.availability(); biometricLockEnabled = await preferences.biometricLockEnabled(); await refreshDevices() }
    func refreshDevices() async { 
        if let loadTask { await loadTask.value; return }
        let previous = activeDevices
        devicesContent = previous.isEmpty ? .loading : .refreshing(previous)
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(previous: previous)
        }
        loadTask = task
        await task.value
        loadTask = nil 
    }
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
    func revoke(_ device: AuthorizedDevice) async { 
        if let task = revocationTasks[device.id] { await task.value; return }
        let task: Task<Void, Never> = Task { [weak self] in
            guard let self else { return }
            await self.performRevoke(device)
        }
        revocationTasks[device.id] = task
        await task.value
        revocationTasks[device.id] = nil 
    }
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


struct ProfilePreferencePresentation: Equatable {
    let title: String
    let value: String
    let detail: String
    let symbol: String
}

enum ProfilePresentation {
    static func displayName(for user: AuthenticatedUser?) -> String {
        let raw = user?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Utilisateur Botaplata" : raw
    }

    static func email(for user: AuthenticatedUser?) -> String? {
        let raw = user?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.contains("@") ? raw : nil
    }

    static func initials(for user: AuthenticatedUser?) -> String {
        let name = displayName(for: user)
        let parts = name.split(separator: " ").filter { !$0.isEmpty }
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        if !letters.isEmpty, name != "Utilisateur Botaplata" { return letters.uppercased() }
        if let first = email(for: user)?.first { return String(first).uppercased() }
        return "BP"
    }

    static func biometricMicrocopy(availability: BiometricAvailability) -> String {
        availability == .available ? "Face ID verrouille l’application sur cet iPhone." : "Indisponible sur cet appareil."
    }

    static func devicesSummary(current: AuthorizedDevice?, others: Int) -> String {
        let currentText = current == nil ? "Aucun appareil actuel identifié" : "Cet iPhone"
        return others == 0 ? currentText : "\(currentText) · \(others) autre\(others > 1 ? "s" : "") appareil\(others > 1 ? "s" : "")"
    }

    static func deviceTitle(_ device: AuthorizedDevice) -> String {
        let name = device.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "iPhone" : name
    }

    static func activityText(_ device: AuthorizedDevice, now: Date = Date()) -> String {
        if device.isRevoked { return "Accès révoqué" }
        if device.isCurrent { return "Actif maintenant" }
        let date = device.lastSeenAt ?? device.lastAuthenticatedAt
        guard let date else { return "Dernière activité inconnue" }
        let rel = RelativeDateTimeFormatter(); rel.locale = Locale(identifier: "fr_FR"); rel.unitsStyle = .full
        return "Dernière activité : " + rel.localizedString(for: date, relativeTo: now)
    }

    static func permissionText(_ status: PushAuthorizationStatus) -> String {
        switch status { case .authorized, .provisional, .ephemeral: "Autorisées"; case .denied: "Désactivées dans iOS"; case .notDetermined: "Non demandées"; case .unknown: "Indisponibles" }
    }

    static func preferenceRows(_ preferences: PushPreferences) -> [ProfilePreferencePresentation] {
        preferences.categories.map { item in
            ProfilePreferencePresentation(title: preferenceTitle(item.eventType), value: item.mandatory ? "Toujours actif" : (item.enabled ? "Activée" : "Désactivée"), detail: preferenceDetail(item.eventType), symbol: preferenceSymbol(item.eventType))
        }
    }

    static func preferenceTitle(_ event: String) -> String {
        ["real_buy_filled":"Ordres", "real_sell_submitted":"Ordres", "real_sell_filled":"Ordres", "real_reconciliation_prolonged":"Vérification nécessaire", "real_monitoring_degraded":"Surveillance", "real_order_rejected":"Alertes critiques", "real_position_opened":"Sessions", "device_revoked":"Sécurité"][event] ?? event.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func preferenceDetail(_ event: String) -> String {
        if event.contains("monitoring") { return "Être prévenu si Botaplata rencontre un problème de suivi." }
        if event.contains("reconciliation") { return "Recevoir une notification lorsqu’une vérification demande votre attention." }
        if event.contains("order") || event.contains("buy") || event.contains("sell") { return "Recevoir une notification lorsqu’un ordre change d’état." }
        if event.contains("position") { return "Être prévenu lorsqu’une session change de position." }
        return "Préférence fournie par le serveur Botaplata."
    }

    static func preferenceSymbol(_ event: String) -> String {
        if event.contains("monitoring") { return "waveform.path.ecg" }
        if event.contains("reconciliation") { return "checklist" }
        if event.contains("order") || event.contains("buy") || event.contains("sell") { return "arrow.left.arrow.right" }
        if event.contains("position") { return "chart.line.uptrend.xyaxis" }
        return "bell"
    }

    static func lastSyncText(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "Inconnue" }
        let rel = RelativeDateTimeFormatter(); rel.locale = Locale(identifier: "fr_FR"); rel.unitsStyle = .short
        return rel.localizedString(for: date, relativeTo: now)
    }
}
