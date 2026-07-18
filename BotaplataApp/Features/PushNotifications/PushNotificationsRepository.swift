import Foundation

nonisolated protocol PushNotificationsRepository: Sendable {
    func registerDevice(token: String, metadata: PushDeviceMetadata, accessToken: String) async throws -> PushDeviceRegistration
    func unregisterCurrentDevice(accessToken: String) async throws
    func fetchPreferences(accessToken: String) async throws -> PushPreferences
    func updatePreferences(_ preferences: PushPreferencesUpdate, accessToken: String) async throws -> PushPreferences
    func fetchNotifications(page: Int, pageSize: Int, filters: NotificationFilters, accessToken: String) async throws -> RealNotificationsPage
    func fetchNotificationSummary(accessToken: String) async throws -> RealNotificationSummary
    func markRead(id: String, accessToken: String) async throws
    func markAllRead(accessToken: String) async throws
}

nonisolated struct RemotePushNotificationsRepository: PushNotificationsRepository {
    let client: APIClientProtocol
    func registerDevice(token: String, metadata: PushDeviceMetadata, accessToken: String) async throws -> PushDeviceRegistration { try await client.send(.init(method: .post, path: "/api/mobile/v1/push-ios/devices/register", headers: HTTPHeaders.bearer(accessToken)), body: RegisterDeviceBody(deviceToken: token, metadata: metadata)) }
    func unregisterCurrentDevice(accessToken: String) async throws { let _: EmptyResponse = try await client.send(.init(method: .delete, path: "/api/mobile/v1/push-ios/devices/current", headers: HTTPHeaders.bearer(accessToken))) }
    func fetchPreferences(accessToken: String) async throws -> PushPreferences { try await client.send(.init(method: .get, path: "/api/mobile/v1/push-ios/preferences", headers: HTTPHeaders.bearer(accessToken))) }
    func updatePreferences(_ preferences: PushPreferencesUpdate, accessToken: String) async throws -> PushPreferences { try await client.send(.init(method: .patch, path: "/api/mobile/v1/push-ios/preferences", headers: HTTPHeaders.bearer(accessToken)), body: preferences) }
    func fetchNotifications(page: Int, pageSize: Int, filters: NotificationFilters, accessToken: String) async throws -> RealNotificationsPage { var q = [URLQueryItem(name: "page", value: "\(page)"), URLQueryItem(name: "page_size", value: "\(pageSize)"), URLQueryItem(name: "unread_only", value: filters.unreadOnly ? "true" : "false")]; if let s = filters.severity { q.append(.init(name: "severity", value: s.rawValue)) }; if let e = filters.eventType { q.append(.init(name: "event_type", value: e)) }; if let id = filters.sessionID { q.append(.init(name: "session_id", value: id)) }; return try await client.send(.init(method: .get, path: "/api/mobile/v1/real/notifications", queryItems: q, headers: HTTPHeaders.bearer(accessToken))) }
    func fetchNotificationSummary(accessToken: String) async throws -> RealNotificationSummary { try await client.send(.init(method: .get, path: "/api/mobile/v1/real/notifications/summary", headers: HTTPHeaders.bearer(accessToken))) }
    func markRead(id: String, accessToken: String) async throws { let _: EmptyResponse = try await client.send(.init(method: .post, path: "/api/mobile/v1/real/notifications/\(id)/read", headers: HTTPHeaders.bearer(accessToken))) }
    func markAllRead(accessToken: String) async throws { let _: EmptyResponse = try await client.send(.init(method: .post, path: "/api/mobile/v1/real/notifications/read-all", headers: HTTPHeaders.bearer(accessToken))) }
    private nonisolated struct RegisterDeviceBody: Encodable, Sendable { let deviceToken: String; let deviceName: String; let environment: PushAPNSEnvironment; let appBundleID: String; let appVersion: String; let osVersion: String; enum CodingKeys: String, CodingKey { case deviceToken = "device_token", deviceName = "device_name", environment, appBundleID = "app_bundle_id", appVersion = "app_version", osVersion = "os_version" }; init(deviceToken: String, metadata: PushDeviceMetadata) { self.deviceToken = deviceToken; deviceName = metadata.deviceName; environment = metadata.environment; appBundleID = metadata.appBundleID; appVersion = metadata.appVersion; osVersion = metadata.osVersion } }
}

nonisolated struct UnconfiguredPushNotificationsRepository: PushNotificationsRepository { func registerDevice(token: String, metadata: PushDeviceMetadata, accessToken: String) async throws -> PushDeviceRegistration { throw APIClientError.network }; func unregisterCurrentDevice(accessToken: String) async throws { throw APIClientError.network }; func fetchPreferences(accessToken: String) async throws -> PushPreferences { throw APIClientError.network }; func updatePreferences(_ preferences: PushPreferencesUpdate, accessToken: String) async throws -> PushPreferences { throw APIClientError.network }; func fetchNotifications(page: Int, pageSize: Int, filters: NotificationFilters, accessToken: String) async throws -> RealNotificationsPage { throw APIClientError.network }; func fetchNotificationSummary(accessToken: String) async throws -> RealNotificationSummary { throw APIClientError.network }; func markRead(id: String, accessToken: String) async throws { throw APIClientError.network }; func markAllRead(accessToken: String) async throws { throw APIClientError.network } }
nonisolated struct MockPushNotificationsRepository: PushNotificationsRepository {
    var items: [RealNotificationItem]
    var preferences: PushPreferences

    init(items: [RealNotificationItem], preferences: PushPreferences) {
        self.items = items
        self.preferences = preferences
    }

    @MainActor
    init() {
        self.init(items: PreviewFixtures.notifications, preferences: PreviewFixtures.pushPreferences)
    }

    @MainActor
    static func preview() -> MockPushNotificationsRepository {
        MockPushNotificationsRepository(items: PreviewFixtures.notifications, preferences: PreviewFixtures.pushPreferences)
    }

    func registerDevice(token: String, metadata: PushDeviceMetadata, accessToken: String) async throws -> PushDeviceRegistration { PushDeviceRegistration(registered: true, environment: metadata.environment, warnings: []) }
    func unregisterCurrentDevice(accessToken: String) async throws {}
    func fetchPreferences(accessToken: String) async throws -> PushPreferences { preferences }
    func updatePreferences(_ preferences: PushPreferencesUpdate, accessToken: String) async throws -> PushPreferences { PushPreferences(categories: self.preferences.categories.map { item in var item = item; if let updated = preferences.categories.first(where: { $0.eventType == item.eventType }), !item.mandatory { item.enabled = updated.enabled }; return item }, updatedAt: Date()) }
    func fetchNotifications(page: Int, pageSize: Int, filters: NotificationFilters, accessToken: String) async throws -> RealNotificationsPage { let filtered = filters.unreadOnly ? items.filter { !$0.isRead } : items; return RealNotificationsPage(items: filtered, pagination: .init(page: page, pageSize: pageSize, total: filtered.count, hasMore: false), warnings: [], serverTime: Date()) }
    func fetchNotificationSummary(accessToken: String) async throws -> RealNotificationSummary { .init(unreadCount: items.filter { !$0.isRead }.count, latestCreatedAt: items.first?.createdAt) }
    func markRead(id: String, accessToken: String) async throws {}
    func markAllRead(accessToken: String) async throws {}
}
