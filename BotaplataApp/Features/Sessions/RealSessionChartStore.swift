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
    func load(sessionID: String) { fetch(sessionID: sessionID, force: false, reason: "sectionOpened") }
    func selectRange(_ range: TradingChartRange, sessionID: String) { guard range != selectedRange else { return }; selectedRange = range; fetch(sessionID: sessionID, force: false, reason: "rangeSelected") }
    func refresh(sessionID: String) { fetch(sessionID: sessionID, force: true, reason: "manualRefresh") }
    func stop() { BotaplataLog.chart.info("ChartStore.stop reason=sectionClosed"); task?.cancel(); task = nil; inFlight = nil; activeRequestID = UUID() }
    private func fetch(sessionID: String, force: Bool, reason: String) {
        let range = selectedRange
        let key = TradingChartCacheKey(sessionID: sessionID, range: range)
        BotaplataLog.chart.info("ChartStore.load session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public) reason=\(reason, privacy: .public)")
        if let entry = cache[key], !force, now().timeIntervalSince(entry.fetchedAt) < range.cacheTTL {
            BotaplataLog.chart.info("ChartStore.cache status=hit session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public)")
            state = .loaded(entry.chart); lastUpdated = entry.fetchedAt; return
        }
        BotaplataLog.chart.info("ChartStore.cache status=miss session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public)")
        if inFlight == key { BotaplataLog.chart.info("ChartStore.request skipped reason=singleFlight session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public)"); return }
        task?.cancel(); let old = cache[key]?.chart ?? (chart?.sessionID == sessionID && chart?.range == range ? chart : nil); state = old.map { .refreshing($0) } ?? .loading; inFlight = key; let requestID = UUID(); activeRequestID = requestID
        task = Task { [repository, authorize] in
            let startedAt = Date()
            BotaplataLog.chart.info("ChartStore.request started session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public) url=/api/mobile/v1/real/sessions/\(sessionID, privacy: .public)/chart?range=\(range.rawValue, privacy: .public)")
            do { let chart = try await authorize { token in try await repository.fetchChart(sessionID: sessionID, range: range, before: nil, limit: nil, accessToken: token) }; try Task.checkCancellation(); await MainActor.run { guard self.activeRequestID == requestID, self.selectedRange == range, chart.sessionID == sessionID, chart.range == range else { BotaplataLog.chart.info("ChartStore.response ignored reason=lateResult session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public)"); return }; let mappingDuration = Date().timeIntervalSince(startedAt); self.remember(chart, for: key); self.state = .loaded(chart); self.lastUpdated = self.now(); self.inFlight = nil; let nonNullLevels = [chart.levels.entryPrice, chart.levels.breakEvenPrice, chart.levels.minimumProfitableExitPrice, chart.levels.trailingStopPrice].compactMap { $0 }.filter { $0 != 0 }.count; BotaplataLog.chart.info("ChartStore.loaded session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public) timeframe=\(chart.timeframe, privacy: .public) candles=\(chart.candles.count, privacy: .public) markers=\(chart.markers.count, privacy: .public) levels=\(nonNullLevels, privacy: .public) warnings=\(chart.warnings.map(\.id).joined(separator: ","), privacy: .public) mappingDuration=\(mappingDuration, privacy: .public)s complete=\(chart.isComplete, privacy: .public) state=loaded") } } catch is CancellationError {} catch { await MainActor.run { guard self.activeRequestID == requestID, self.selectedRange == range else { return }; if let entry = self.cache[key] { self.state = .offline(entry.chart); BotaplataLog.chart.info("ChartStore.loaded session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public) state=offline cache=hit") } else { self.state = .failed(Self.map(error)); BotaplataLog.chart.error("ChartStore.loaded session=\(sessionID, privacy: .public) range=\(range.rawValue, privacy: .public) state=failed cache=miss error=\(String(describing: error), privacy: .public)") }; self.inFlight = nil } }
        }
    }
    private func remember(_ chart: TradingChart, for key: TradingChartCacheKey) { cache[key] = .init(chart: chart, fetchedAt: now()); if cache.count > limit, let oldest = cache.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key { cache.removeValue(forKey: oldest) } }
    private static func map(_ error: Error) -> ChartPresentationError { if let e = error as? AuthenticationError { switch e { case .offline: return .networkUnavailable; case .accessTokenExpired: return .authenticationExpired; case .deviceRevoked: return .deviceRevoked; case .contractIncompatible: return .contractIncompatible; case .decodingFailed: return .decodingFailed; default: return .serverUnavailable } }; return .unknown }
    #if DEBUG
    func seedCache(chart: TradingChart, fetchedAt: Date) { remember(chart, for: TradingChartCacheKey(sessionID: chart.sessionID, range: chart.range)); cache[TradingChartCacheKey(sessionID: chart.sessionID, range: chart.range)] = .init(chart: chart, fetchedAt: fetchedAt) }
    var cacheCount: Int { cache.count }
    func hasCache(sessionID: String, range: TradingChartRange) -> Bool { cache[TradingChartCacheKey(sessionID: sessionID, range: range)] != nil }
    #endif
}
