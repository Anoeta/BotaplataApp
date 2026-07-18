import Foundation
import Observation

struct TradingChartCacheKey: Hashable { let sessionID: String; let range: TradingChartRange }
struct TradingChartCacheEntry { let chart: TradingChart; let fetchedAt: Date }
enum ChartPresentationError: Equatable { case networkUnavailable, serverUnavailable, authenticationExpired, deviceRevoked, decodingFailed, contractIncompatible, unknown; var title: String { switch self { case .networkUnavailable: "Impossible de charger le graphique"; case .contractIncompatible: "Réponse du serveur incompatible"; default: "Graphique indisponible" } }; var message: String { switch self { case .networkUnavailable: "Vérifiez la connexion au serveur Botaplata."; case .contractIncompatible: "Vérifiez que le serveur et l’application Botaplata sont à jour."; default: "Réessayez dans quelques instants." } } }
enum RealSessionChartState: Equatable { case idle, loading, loaded(TradingChart), refreshing(TradingChart), offline(TradingChart), failed(ChartPresentationError) }

@MainActor @Observable final class RealSessionChartStore {
    var selectedRange: TradingChartRange = .sixHours; var state: RealSessionChartState = .idle; var lastUpdated: Date?; private let repository: RealSessionChartRepositoryProtocol; private let authSession: AuthenticationSession; private var cache: [TradingChartCacheKey: TradingChartCacheEntry] = [:]; private var task: Task<Void, Never>?; private var inFlight: TradingChartCacheKey?; private let limit = 16
    init(repository: RealSessionChartRepositoryProtocol, authSession: AuthenticationSession) { self.repository = repository; self.authSession = authSession }
    var chart: TradingChart? { switch state { case .loaded(let c), .refreshing(let c), .offline(let c): c; default: nil } }
    var warnings: [Warning] { chart?.warnings ?? [] }
    func load(sessionID: String) { fetch(sessionID: sessionID, force: false) }
    func selectRange(_ range: TradingChartRange, sessionID: String) { guard range != selectedRange else { return }; selectedRange = range; fetch(sessionID: sessionID, force: false) }
    func refresh(sessionID: String) { fetch(sessionID: sessionID, force: true) }
    func stop() { task?.cancel(); task = nil; inFlight = nil }
    private func fetch(sessionID: String, force: Bool) { let key = TradingChartCacheKey(sessionID: sessionID, range: selectedRange); if let entry = cache[key], !force, Date().timeIntervalSince(entry.fetchedAt) < selectedRange.cacheTTL { state = .loaded(entry.chart); lastUpdated = entry.fetchedAt; return }; if inFlight == key { return }; task?.cancel(); let old = chart?.range == selectedRange ? chart : nil; state = old.map { .refreshing($0) } ?? .loading; inFlight = key; task = Task { [repository, authSession, range = selectedRange] in do { let chart = try await authSession.withAccessTokenReplay { token in try await repository.fetchChart(sessionID: sessionID, range: range, before: nil, limit: nil, accessToken: token) }; try Task.checkCancellation(); await MainActor.run { self.remember(chart, for: key); self.state = .loaded(chart); self.lastUpdated = Date(); self.inFlight = nil } } catch is CancellationError {} catch { await MainActor.run { if let entry = self.cache[key] { self.state = .offline(entry.chart) } else { self.state = .failed(Self.map(error)) }; self.inFlight = nil } } } }
    private func remember(_ chart: TradingChart, for key: TradingChartCacheKey) { cache[key] = .init(chart: chart, fetchedAt: Date()); if cache.count > limit, let oldest = cache.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key { cache.removeValue(forKey: oldest) } }
    private static func map(_ error: Error) -> ChartPresentationError { if let e = error as? AuthenticationError { switch e { case .offline: return .networkUnavailable; case .accessTokenExpired: return .authenticationExpired; case .deviceRevoked: return .deviceRevoked; case .contractIncompatible: return .contractIncompatible; default: return .serverUnavailable } }; return .unknown }
}
