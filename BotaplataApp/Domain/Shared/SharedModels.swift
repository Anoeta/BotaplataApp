import Foundation

enum DataSource: String, Sendable, Codable { case previewFixture, localCache, backend, unknown }
enum FreshnessStatus: String, Sendable, Codable { case fresh, aging, stale, cached, unknown }
struct DataFreshness: Equatable, Sendable, Codable { let status: FreshnessStatus; let updatedAt: Date?; let source: DataSource }
enum LoadedContent<Value: Sendable>: Sendable { case idle, loading, loaded(Value), loadedFromCache(Value), refreshing(Value?), partial(Value), stale(Value), offline(Value?), error(String) }
enum AlertSeverity: String, Sendable, Codable { case information, warning, critical }
struct Warning: Identifiable, Equatable, Sendable, Codable { let id: String; let severity: AlertSeverity; let title: String; let message: String }
