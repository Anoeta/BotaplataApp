import Foundation
import Observation

struct TradingChartCacheKey: Hashable { let sessionID: String; let range: TradingChartRange }
struct TradingChartCacheEntry { let chart: TradingChart; let fetchedAt: Date }
enum ChartPresentationError: Equatable { case networkUnavailable, serverUnavailable, authenticationExpired, deviceRevoked, decodingFailed, contractIncompatible, unknown; var title: String { switch self { case .networkUnavailable: "Impossible de charger le graphique"; case .contractIncompatible: "Réponse du serveur incompatible"; default: "Graphique indisponible" } }; var message: String { switch self { case .networkUnavailable: "Vérifiez la connexion au serveur Botaplata."; case .contractIncompatible: "Vérifiez que le serveur et l’application Botaplata sont à jour."; default: "Réessayez dans quelques instants." } } }
enum RealSessionChartState: Equatable { case idle, loading, loaded(TradingChart), refreshing(TradingChart), offline(TradingChart), failed(ChartPresentationError) }

typealias ChartAuthorization = @Sendable (@escaping @Sendable (String) async throws -> TradingChart) async throws -> TradingChart

@MainActor @Observable final class RealSessionChartStore {
    var selectedRange: TradingChartRange = .sixHours; var state: RealSessionChartState = .idle; var lastUpdated: Date?; private let repository: RealSessionChartRepositoryProtocol; private let authorize: ChartAuthorization; private var cache: [TradingChartCacheKey: TradingChartCacheEntry] = [:]; private var task: Task<Void, Never>?; private var inFlight: TradingChartCacheKey?; private var activeRequestID = UUID(); private let limit = 16; private let now: () -> Date
    init(repository: RealSessionChartRepositoryProtocol, authSession: AuthenticationSession, now: @escaping () -> Date = Date.init) { self.repository = repository; self.authorize = { work in try await authSession.withAccessTokenReplay(work) }; self.now = now }
    init(repository: RealSessionChartRepositoryProtocol, authorize: @escaping ChartAuthorization, now: @escaping () -> Date = Date.init) { self.repository = repository; self.authorize = authorize; self.now = now }
    var chart: TradingChart? { switch state { case .loaded(let c), .refreshing(let c), .offline(let c): c; default: nil } }
    var warnings: [Warning] { Array(Dictionary(grouping: chart?.warnings ?? [], by: \.id).compactMap { $0.value.first }) }
    func load(sessionID: String) { fetch(sessionID: sessionID, force: false) }
    func selectRange(_ range: TradingChartRange, sessionID: String) { guard range != selectedRange else { return }; selectedRange = range; fetch(sessionID: sessionID, force: false) }
    func refresh(sessionID: String) { fetch(sessionID: sessionID, force: true) }
    func stop() { task?.cancel(); task = nil; inFlight = nil; activeRequestID = UUID() }
    private func fetch(sessionID: String, force: Bool) { let range = selectedRange; let key = TradingChartCacheKey(sessionID: sessionID, range: range); if let entry = cache[key], !force, now().timeIntervalSince(entry.fetchedAt) < range.cacheTTL { state = .loaded(entry.chart); lastUpdated = entry.fetchedAt; return }; if inFlight == key { return }; task?.cancel(); let old = cache[key]?.chart ?? (chart?.sessionID == sessionID && chart?.range == range ? chart : nil); state = old.map { .refreshing($0) } ?? .loading; inFlight = key; let requestID = UUID(); activeRequestID = requestID; task = Task { [repository, authorize] in do { let chart = try await authorize { token in try await repository.fetchChart(sessionID: sessionID, range: range, before: nil, limit: nil, accessToken: token) }; try Task.checkCancellation(); await MainActor.run { guard self.activeRequestID == requestID, self.selectedRange == range, chart.sessionID == sessionID, chart.range == range else { return }; self.remember(chart, for: key); self.state = .loaded(chart); self.lastUpdated = self.now(); self.inFlight = nil } } catch is CancellationError {} catch { await MainActor.run { guard self.activeRequestID == requestID, self.selectedRange == range else { return }; if let entry = self.cache[key] { self.state = .offline(entry.chart) } else { self.state = .failed(Self.map(error)) }; self.inFlight = nil } } } }
    private func remember(_ chart: TradingChart, for key: TradingChartCacheKey) { cache[key] = .init(chart: chart, fetchedAt: now()); if cache.count > limit, let oldest = cache.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key { cache.removeValue(forKey: oldest) } }
    private static func map(_ error: Error) -> ChartPresentationError { if let e = error as? AuthenticationError { switch e { case .offline: return .networkUnavailable; case .accessTokenExpired: return .authenticationExpired; case .deviceRevoked: return .deviceRevoked; case .contractIncompatible: return .contractIncompatible; case .decodingFailed: return .decodingFailed; default: return .serverUnavailable } }; return .unknown }
    #if DEBUG
    func seedCache(chart: TradingChart, fetchedAt: Date) { remember(chart, for: TradingChartCacheKey(sessionID: chart.sessionID, range: chart.range)); cache[TradingChartCacheKey(sessionID: chart.sessionID, range: chart.range)] = .init(chart: chart, fetchedAt: fetchedAt) }
    var cacheCount: Int { cache.count }
    func hasCache(sessionID: String, range: TradingChartRange) -> Bool { cache[TradingChartCacheKey(sessionID: sessionID, range: range)] != nil }
    #endif
}
