import Foundation

nonisolated struct PushDeviceMetadata: Codable, Equatable, Sendable { let deviceName: String; let environment: PushAPNSEnvironment; let appBundleID: String; let appVersion: String; let osVersion: String; enum CodingKeys: String, CodingKey { case deviceName = "device_name", environment, appBundleID = "app_bundle_id", appVersion = "app_version", osVersion = "os_version" } }
nonisolated enum PushAPNSEnvironment: String, Codable, Sendable { case sandbox, production }
nonisolated struct PushDeviceRegistration: Codable, Equatable, Sendable { let registered: Bool; let environment: PushAPNSEnvironment?; let warnings: [APIWarning]? }
nonisolated struct PushPreferences: Codable, Equatable, Sendable { var categories: [PushPreferenceItem]; let updatedAt: Date?; enum CodingKeys: String, CodingKey { case categories, updatedAt = "updated_at" }
    init(categories: [PushPreferenceItem], updatedAt: Date?) { self.categories = categories; self.updatedAt = updatedAt }
    init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); categories = try c.decodeIfPresent([PushPreferenceItem].self, forKey: .categories) ?? []; updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) }
}
nonisolated struct PushPreferenceItem: Codable, Equatable, Identifiable, Sendable { let eventType: String; var enabled: Bool; let mandatory: Bool; let severity: NotificationSeverity?; var id: String { eventType }; enum CodingKeys: String, CodingKey { case eventType = "event_type", enabled, mandatory, severity } }
nonisolated struct PushPreferencesUpdate: Codable, Equatable, Sendable { let categories: [PushPreferenceUpdateItem] }
nonisolated struct PushPreferenceUpdateItem: Codable, Equatable, Sendable { let eventType: String; let enabled: Bool; enum CodingKeys: String, CodingKey { case eventType = "event_type", enabled } }

nonisolated struct NotificationFilters: Equatable, Sendable { var unreadOnly = false; var severity: NotificationSeverity?; var eventType: String?; var sessionID: String? }
nonisolated struct RealNotificationsPage: Codable, Equatable, Sendable { let items: [RealNotificationItem]; let pagination: RealNotificationsPagination; let warnings: [APIWarning]?; let serverTime: Date?; enum CodingKeys: String, CodingKey { case items, pagination, warnings; case serverTime = "server_time" } }
nonisolated struct RealNotificationsPagination: Codable, Equatable, Sendable { let page: Int; let pageSize: Int; let total: Int?; let hasMore: Bool; enum CodingKeys: String, CodingKey { case page, total; case pageSize = "page_size", hasMore = "has_more" } }
nonisolated struct RealNotificationSummary: Codable, Equatable, Sendable { let unreadCount: Int; let latestCreatedAt: Date?; enum CodingKeys: String, CodingKey { case unreadCount = "unread_count", latestCreatedAt = "latest_created_at" } }
nonisolated struct RealNotificationItem: Codable, Equatable, Identifiable, Sendable { let id: String; let eventType: String; let severity: NotificationSeverity; let title: String; let message: String; let createdAt: Date; var isRead: Bool; let sessionID: String?; let symbol: String?; let provider: String?; let navigationTarget: NotificationNavigationTarget?; let money: NotificationMoney?; enum CodingKeys: String, CodingKey { case id, severity, title, message, provider, money; case eventType = "event_type", createdAt = "created_at", isRead = "is_read", sessionID = "session_id", symbol, navigationTarget = "navigation_target" } }
nonisolated enum NotificationSeverity: String, Codable, CaseIterable, Sendable { case info, watch, warning, critical; var label: String { switch self { case .info: "Information"; case .watch: "À surveiller"; case .warning: "Attention"; case .critical: "Critique" } } }
nonisolated struct NotificationMoney: Codable, Equatable, Sendable { let amountQuote: DecimalString?; let currency: String?; enum CodingKeys: String, CodingKey { case amountQuote = "amount_quote", currency } }
nonisolated struct NotificationNavigationTarget: Codable, Equatable, Sendable { let kind: Kind; let sessionID: String?; let section: Section; nonisolated enum Kind: String, Codable, Sendable { case session, journal, orders, chart, unknown }; nonisolated enum Section: String, Codable, CaseIterable, Sendable { case overview, journal, orders, decisions, chart }
    enum CodingKeys: String, CodingKey { case kind, sessionID = "session_id", section }
    init(kind: Kind, sessionID: String?, section: Section = .overview) { self.kind = kind; self.sessionID = sessionID; self.section = section }
    init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); kind = (try? c.decode(Kind.self, forKey: .kind)) ?? .unknown; sessionID = try? c.decodeIfPresent(String.self, forKey: .sessionID); section = (try? c.decode(Section.self, forKey: .section)) ?? .overview }
}
