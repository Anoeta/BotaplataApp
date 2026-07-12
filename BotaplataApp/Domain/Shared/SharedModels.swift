import Foundation

enum DataSource: String, Sendable { case previewFixture, localCache, backend, unknown }
enum FreshnessStatus: String, Sendable { case fresh, aging, stale, cached, unknown }
struct DataFreshness: Equatable, Sendable { let status: FreshnessStatus; let updatedAt: Date?; let source: DataSource }
enum LoadedContent<Value: Sendable>: Sendable { case idle, loading, loaded(Value), loadedFromCache(Value), refreshing(Value?), partial(Value), stale(Value), offline(Value?), error(String) }
enum AlertSeverity: String, Sendable { case information, warning, critical }
struct Warning: Identifiable, Equatable, Sendable { let id: String; let severity: AlertSeverity; let title: String; let message: String }
