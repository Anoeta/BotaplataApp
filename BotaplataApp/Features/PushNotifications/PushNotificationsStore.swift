import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class PushNotificationsStore {
    var permissionStatus: PushAuthorizationStatus = .unknown
    var registrationMessage: String?
    var preferences: LoadedContent<PushPreferences> = .idle
    var notifications: LoadedContent<[RealNotificationItem]> = .idle
    var summary: RealNotificationSummary?
    var filters = NotificationFilters()
    var pendingNavigationTarget: NotificationNavigationTarget?
    var savingPreferenceEventTypes: Set<String> = []
    var preferenceMessage: String?

    private let repository: PushNotificationsRepository
    private let permissionManager: PushNotificationPermissionManaging
    private let cache: PushNotificationsCache
    private let authSession: AuthenticationSession
    private let appState: AppState
    private let badgeManager: AppBadgeManaging
    private var loadTask: Task<Void, Never>?
    private var generation = 0
    private var lastPreferencesLoadAt: Date?
    private var didBootstrap = false
    private let preferencesCacheTTL: TimeInterval = 60

    init(repository: PushNotificationsRepository, permissionManager: PushNotificationPermissionManaging, cache: PushNotificationsCache, authSession: AuthenticationSession, appState: AppState, badgeManager: AppBadgeManaging = AppBadgeManager()) {
        self.repository = repository
        self.permissionManager = permissionManager
        self.cache = cache
        self.authSession = authSession
        self.appState = appState
        self.badgeManager = badgeManager
    }

    var unreadCount: Int { self.summary?.unreadCount ?? 0 }

    func bootstrap() async {
        if didBootstrap { BotaplataLog.network.debug("PushPreferencesStore.load skipped reason=alreadyBootstrapped"); return }
        didBootstrap = true
        BotaplataLog.network.debug("PushPreferencesStore.load reason=bootstrap")
        self.permissionStatus = await self.permissionManager.authorizationStatus()
        if let cached = await self.cache.load() {
            self.notifications = .loadedFromCache(cached.notifications)
            self.summary = cached.summary
            self.preferences = cached.preferences.map { .loadedFromCache($0) } ?? .idle
            await self.updateBadge()
        }
        await self.refreshAll(reason: "bootstrap")
    }

    func refreshAll(reason: String = "refresh", force: Bool = false) async {
        if reason != "bootstrap" { BotaplataLog.network.debug("PushPreferencesStore.load reason=\(reason, privacy: .public)") }
        if self.loadTask != nil { BotaplataLog.network.debug("PushPreferencesStore.load skipped reason=singleFlight"); return }
        if !force, let lastPreferencesLoadAt, Date().timeIntervalSince(lastPreferencesLoadAt) < preferencesCacheTTL { BotaplataLog.network.debug("PushPreferencesStore.load skipped reason=freshCache"); return }
        let nextGeneration = self.generation + 1
        self.generation = nextGeneration
        self.loadTask = Task { await self.load(generation: nextGeneration) }
        await self.loadTask?.value
        self.loadTask = nil
    }

    private func load(generation: Int) async {
        let cached = await self.cache.load()
        do {
            let prefs = try await self.withReplay { token in
                try await self.repository.fetchPreferences(accessToken: token)
            }
            let page = try await self.withReplay { token in
                try await self.repository.fetchNotifications(page: 1, pageSize: 50, filters: self.filters, accessToken: token)
            }
            let sum = try await self.withReplay { token in
                try await self.repository.fetchNotificationSummary(accessToken: token)
            }
            guard generation == self.generation else { return }
            self.preferences = .loaded(prefs)
            self.lastPreferencesLoadAt = Date()
            self.notifications = .loaded(page.items)
            self.summary = sum
            await self.cache.save(.init(notifications: page.items, summary: sum, preferences: prefs, savedAt: Date()))
            await self.updateBadge()
        } catch {
            self.handle(error)
            if let cached {
                self.preferences = cached.preferences.map { .loadedFromCache($0) } ?? self.preferences
                self.notifications = .offline(cached.notifications)
                self.summary = cached.summary
            } else {
                self.notifications = .error("Impossible de charger les alertes\nVérifiez votre connexion puis réessayez.")
            }
        }
    }

    func requestPermission() async {
        do { self.permissionStatus = try await self.permissionManager.requestAuthorizationAndRegister() }
        catch { self.registrationMessage = "Les notifications n'ont pas pu être activées." }
    }

    func registerDeviceToken(_ token: String) async {
        guard !token.isEmpty else { return }
        do {
            _ = try await self.withReplay { accessToken in
                try await self.repository.registerDevice(token: token, metadata: Self.deviceMetadata(environment: self.appState.environment), accessToken: accessToken)
            }
            self.registrationMessage = "Notifications activées sur cet iPhone."
        } catch { self.registrationMessage = nil }
    }

    func unregisterCurrentDevice() async {
        do {
            try await self.withReplay { accessToken in try await self.repository.unregisterCurrentDevice(accessToken: accessToken) }
            self.registrationMessage = "Notifications désactivées sur cet iPhone."
        } catch { self.registrationMessage = "Désactivation impossible pour le moment." }
    }

    func updatePreference(_ item: PushPreferenceItem, enabled: Bool) async {
        guard !item.mandatory, !savingPreferenceEventTypes.contains(item.eventType) else { return }
        let previous = currentPreferences()
        savingPreferenceEventTypes.insert(item.eventType)
        preferenceMessage = nil
        do {
            let current = self.currentPreferences()
            let update = PushPreferencesUpdate(categories: current.categories.map { preference in
                .init(eventType: preference.eventType, enabled: preference.eventType == item.eventType ? enabled : preference.enabled)
            })
            let prefs = try await self.withReplay { token in try await self.repository.updatePreferences(update, accessToken: token) }
            self.preferences = .loaded(prefs)
            self.preferenceMessage = "Préférence enregistrée."
            await self.saveCache(preferences: prefs)
        } catch { self.preferences = .loaded(previous); self.preferenceMessage = "Impossible d’enregistrer ce réglage. Vérifiez la connexion au serveur Botaplata."; self.handle(error) }
        savingPreferenceEventTypes.remove(item.eventType)
    }

    func markRead(_ item: RealNotificationItem) async {
        self.applyRead(id: item.id)
        Task { [self] in
            do {
                try await self.withReplay { token in try await self.repository.markRead(id: item.id, accessToken: token) }
                await self.refreshSummary()
            } catch {}
        }
    }

    func markAllRead() async {
        self.setAllRead()
        do {
            try await self.withReplay { token in try await self.repository.markAllRead(accessToken: token) }
            await self.refreshSummary()
        } catch {}
    }

    func handleNotificationTap(target: NotificationNavigationTarget?, notificationID: String?, router: AppRouter) async {
        if let id = notificationID {
            self.applyRead(id: id)
            Task { [self] in
                try? await self.withReplay { token in try await self.repository.markRead(id: id, accessToken: token) }
                await self.refreshSummary()
            }
        }
        guard let target else { return }
        if self.appState.sessionState == .lockedLocally {
            self.pendingNavigationTarget = target
            return
        }
        router.route(to: target)
    }

    func applyPendingNavigationIfPossible(router: AppRouter) {
        guard self.appState.sessionState == .authenticated, let target = self.pendingNavigationTarget else { return }
        self.pendingNavigationTarget = nil
        router.route(to: target)
    }

    func purge() async {
        self.generation += 1
        self.notifications = .idle
        self.preferences = .idle
        self.summary = nil
        self.pendingNavigationTarget = nil
        self.savingPreferenceEventTypes.removeAll()
        self.preferenceMessage = nil
        await self.cache.purge()
        await self.updateBadge()
    }

    private func refreshSummary() async {
        do {
            self.summary = try await self.withReplay { token in try await self.repository.fetchNotificationSummary(accessToken: token) }
            await self.saveCache(preferences: self.currentPreferences())
            await self.updateBadge()
        } catch {}
    }

    private func updateBadge() async { await self.badgeManager.setBadgeCount(self.summary?.unreadCount ?? 0) }

    private func withReplay<T: Sendable>(_ work: @escaping @Sendable (String) async throws -> T) async throws -> T {
        do { return try await self.authSession.withAccessTokenReplay(work) }
        catch let error as AuthenticationError where error == .accessTokenExpired { self.appState.markExpired(); throw error }
        catch let error as AuthenticationError where error == .deviceRevoked { self.appState.markRevoked(); throw error }
        catch { throw error }
    }

    private func handle(_ error: Error) {
        if (error as? AuthenticationError) == .deviceRevoked { self.appState.markRevoked() }
        else if (error as? AuthenticationError) == .accessTokenExpired { self.appState.markExpired() }
    }

    func currentPreferencesSnapshot() -> PushPreferences { currentPreferences() }

    private func currentPreferences() -> PushPreferences {
        switch self.preferences {
        case .loaded(let value), .loadedFromCache(let value), .refreshing(let value?), .offline(let value?), .partial(let value), .stale(let value): return value
        default: return PushPreferences(categories: [], updatedAt: nil)
        }
    }

    private func currentItems() -> [RealNotificationItem] {
        switch self.notifications {
        case .loaded(let value), .loadedFromCache(let value), .refreshing(let value?), .offline(let value?), .partial(let value), .stale(let value): return value
        default: return []
        }
    }

    private func applyRead(id: String) {
        let updated = self.currentItems().map { item in
            var copy = item
            if copy.id == id { copy.isRead = true }
            return copy
        }
        self.notifications = .loaded(updated)
        self.summary = .init(unreadCount: max(0, self.unreadCount - 1), latestCreatedAt: self.summary?.latestCreatedAt)
        Task { [self] in await self.updateBadge() }
    }

    private func setAllRead() {
        self.notifications = .loaded(self.currentItems().map { item in var copy = item; copy.isRead = true; return copy })
        self.summary = .init(unreadCount: 0, latestCreatedAt: self.summary?.latestCreatedAt)
        Task { [self] in await self.updateBadge() }
    }

    private func saveCache(preferences prefs: PushPreferences) async {
        await self.cache.save(.init(notifications: self.currentItems(), summary: self.summary, preferences: prefs, savedAt: Date()))
    }

    static func deviceMetadata(environment: AppEnvironment) -> PushDeviceMetadata {
        #if canImport(UIKit)
        let device = UIDevice.current; let name = device.name; let os = device.systemVersion
        #else
        let name = "iPhone"; let os = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        let bundle = Bundle.main
        return PushDeviceMetadata(deviceName: name, environment: environment.isProductionData ? .production : .sandbox, appBundleID: bundle.bundleIdentifier ?? "unknown", appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown", osVersion: os)
    }
}

extension AppRouter {
    func route(to target: NotificationNavigationTarget) {
        guard target.kind == .session, let id = target.sessionID else { return }
        self.selectedTab = target.section == .journal ? .journal : .sessions
        self.sessionsPath.append(SessionRoute.detail(id: id, section: target.section))
        if target.section == .journal { self.journalPath.append(SessionRoute.detail(id: id, section: .journal)) }
    }
}

enum SessionRoute: Hashable { case detail(id: String, section: NotificationNavigationTarget.Section) }

extension PushNotificationsStore {
    static func preview(status: PushAuthorizationStatus = .authorized) -> PushNotificationsStore {
        let state = AppState.demo()
        let auth = AuthenticationStore(repository: MockAuthenticationRepository(), tokenStore: InMemoryTokenStore(), appState: state)
        return PushNotificationsStore(repository: MockPushNotificationsRepository(), permissionManager: MockPushNotificationPermissionManager(status: status), cache: FilePushNotificationsCache(directory: FileManager.default.temporaryDirectory), authSession: auth.session, appState: state, badgeManager: MockAppBadgeManager())
    }
}
