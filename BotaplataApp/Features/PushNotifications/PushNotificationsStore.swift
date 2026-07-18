import Foundation
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
    private let repository: PushNotificationsRepository; private let permissionManager: PushNotificationPermissionManaging; private let cache: PushNotificationsCache; private let authSession: AuthenticationSession; private let appState: AppState; private let badgeManager: AppBadgeManaging; private var loadTask: Task<Void, Never>?; private var generation = 0
    init(repository: PushNotificationsRepository, permissionManager: PushNotificationPermissionManaging, cache: PushNotificationsCache, authSession: AuthenticationSession, appState: AppState, badgeManager: AppBadgeManaging = AppBadgeManager()) { self.repository = repository; self.permissionManager = permissionManager; self.cache = cache; self.authSession = authSession; self.appState = appState; self.badgeManager = badgeManager }
    var unreadCount: Int { summary?.unreadCount ?? 0 }
    func bootstrap() async { permissionStatus = await self.permissionManager.authorizationStatus(); if let cached = await self.cache.load() { notifications = .loadedFromCache(cached.notifications); summary = cached.summary; preferences = cached.preferences.map { .loadedFromCache($0) } ?? .idle; await self.updateBadge() }; await self.refreshAll() }
    func refreshAll() async { if loadTask != nil { return }; let g = generation + 1; generation = g; loadTask = Task { await self.load(generation: g) }; await loadTask?.value; loadTask = nil }
    private func load(generation: Int) async { let cached = await self.cache.load(); do { let prefs = try await self.withReplay { try await self.repository.fetchPreferences(accessToken: $0) }; let page = try await self.withReplay { try await self.repository.fetchNotifications(page: 1, pageSize: 50, filters: self.filters, accessToken: $0) }; let sum = try await self.withReplay { try await self.repository.fetchNotificationSummary(accessToken: $0) }; guard generation == self.generation else { return }; preferences = .loaded(prefs); notifications = .loaded(page.items); summary = sum; await self.cache.save(.init(notifications: page.items, summary: sum, preferences: prefs, savedAt: Date())); await self.updateBadge() } catch { handle(error); if let cached { preferences = cached.preferences.map { .loadedFromCache($0) } ?? preferences; notifications = .offline(cached.notifications); summary = cached.summary } else { notifications = .error("Impossible de charger les alertes\nVérifiez votre connexion puis réessayez.") } } }
    func requestPermission() async { do { permissionStatus = try await self.permissionManager.requestAuthorizationAndRegister() } catch { registrationMessage = "Les notifications n'ont pas pu être activées." } }
    func registerDeviceToken(_ token: String) async { guard !token.isEmpty else { return }; do { _ = try await self.withReplay { try await self.repository.registerDevice(token: token, metadata: Self.deviceMetadata(environment: self.appState.environment), accessToken: $0) }; registrationMessage = "Notifications activées sur cet iPhone." } catch { registrationMessage = nil } }
    func unregisterCurrentDevice() async { do { try await self.withReplay { try await self.repository.unregisterCurrentDevice(accessToken: $0) }; registrationMessage = "Notifications désactivées sur cet iPhone." } catch { registrationMessage = "Désactivation impossible pour le moment." } }
    func updatePreference(_ item: PushPreferenceItem, enabled: Bool) async { guard !item.mandatory else { return }; do { let current = currentPreferences(); let update = PushPreferencesUpdate(categories: current.categories.map { .init(eventType: $0.eventType, enabled: $0.eventType == item.eventType ? enabled : $0.enabled) }); let prefs = try await self.withReplay { try await self.repository.updatePreferences(update, accessToken: $0) }; preferences = .loaded(prefs); await self.saveCache(preferences: prefs) } catch { handle(error) } }
    func markRead(_ item: RealNotificationItem) async { applyRead(id: item.id); Task { do { try await self.withReplay { try await self.repository.markRead(id: item.id, accessToken: $0) }; await self.refreshSummary() } catch {} } }
    func markAllRead() async { setAllRead(); do { try await self.withReplay { try await self.repository.markAllRead(accessToken: $0) }; await self.refreshSummary() } catch { } }
    func handleNotificationTap(target: NotificationNavigationTarget?, notificationID: String?, router: AppRouter) async { if let id = notificationID { applyRead(id: id); Task { try? await self.withReplay { try await self.repository.markRead(id: id, accessToken: $0) }; await self.refreshSummary() } }; guard let target else { return }; if self.appState.sessionState == .lockedLocally { self.pendingNavigationTarget = target; return }; router.route(to: target) }
    func applyPendingNavigationIfPossible(router: AppRouter) { guard self.appState.sessionState == .authenticated, let target = self.pendingNavigationTarget else { return }; self.pendingNavigationTarget = nil; router.route(to: target) }
    func purge() async { generation += 1; notifications = .idle; preferences = .idle; summary = nil; self.pendingNavigationTarget = nil; await self.cache.purge(); await self.updateBadge() }
    private func refreshSummary() async { do { summary = try await self.withReplay { try await self.repository.fetchNotificationSummary(accessToken: $0) }; await self.saveCache(preferences: currentPreferences()); await self.updateBadge() } catch {} }
    private func updateBadge() async { await self.badgeManager.setBadgeCount(summary?.unreadCount ?? 0) }
    private func withReplay<T: Sendable>(_ work: @escaping @Sendable (String) async throws -> T) async throws -> T { do { return try await self.authSession.withAccessTokenReplay(work) } catch let error as AuthenticationError where error == .accessTokenExpired { self.appState.markExpired(); throw error } catch let error as AuthenticationError where error == .deviceRevoked { self.appState.markRevoked(); throw error } catch { throw error } }
    private func handle(_ error: Error) { if (error as? AuthenticationError) == .deviceRevoked { self.appState.markRevoked() } else if (error as? AuthenticationError) == .accessTokenExpired { self.appState.markExpired() } }
    private func currentPreferences() -> PushPreferences { switch preferences { case .loaded(let p), .loadedFromCache(let p), .refreshing(let p?), .offline(let p?), .partial(let p), .stale(let p): return p; default: return PushPreferences(categories: [], updatedAt: nil) } }
    private func currentItems() -> [RealNotificationItem] { switch notifications { case .loaded(let v), .loadedFromCache(let v), .refreshing(let v?), .offline(let v?), .partial(let v), .stale(let v): return v; default: return [] } }
    private func applyRead(id: String) { let updated = currentItems().map { item in var copy = item; if copy.id == id { copy.isRead = true }; return copy }; notifications = .loaded(updated); summary = .init(unreadCount: max(0, unreadCount - 1), latestCreatedAt: summary?.latestCreatedAt); Task { await self.updateBadge() } }
    private func setAllRead() { notifications = .loaded(currentItems().map { var copy = $0; copy.isRead = true; return copy }); summary = .init(unreadCount: 0, latestCreatedAt: summary?.latestCreatedAt); Task { await self.updateBadge() } }
    private func saveCache(preferences prefs: PushPreferences) async { await self.cache.save(.init(notifications: currentItems(), summary: summary, preferences: prefs, savedAt: Date())) }
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

extension AppRouter { func route(to target: NotificationNavigationTarget) { guard target.kind == .session, let id = target.sessionID else { return }; selectedTab = target.section == .journal ? .journal : .sessions; sessionsPath.append(SessionRoute.detail(id: id, section: target.section)); if target.section == .journal { journalPath.append(SessionRoute.detail(id: id, section: .journal)) } } }
enum SessionRoute: Hashable { case detail(id: String, section: NotificationNavigationTarget.Section) }
extension PushNotificationsStore { static func preview(status: PushAuthorizationStatus = .authorized) -> PushNotificationsStore { let state = AppState.demo(); let auth = AuthenticationStore(repository: MockAuthenticationRepository(), tokenStore: InMemoryTokenStore(), appState: state); return PushNotificationsStore(repository: MockPushNotificationsRepository(), permissionManager: MockPushNotificationPermissionManager(status: status), cache: FilePushNotificationsCache(directory: FileManager.default.temporaryDirectory), authSession: auth.session, appState: state, badgeManager: MockAppBadgeManager()) } }
