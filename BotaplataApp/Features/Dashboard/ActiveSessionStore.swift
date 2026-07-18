import Foundation
import Observation

protocol AppClock: Sendable { func sleep(seconds: TimeInterval) async throws }
struct SystemAppClock: AppClock { func sleep(seconds: TimeInterval) async throws { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) } }

@MainActor
@Observable
final class ActiveSessionStore {
    var content: LoadedContent<RealActiveSnapshot> = .idle
    private let repository: RealActiveSnapshotRepository; private let cache: ActiveSessionCache; private let authSession: AuthenticationSession; private let appState: AppState; private let clock: AppClock
    private var refreshTask: Task<Void, Never>?; private var pollingTask: Task<Void, Never>?; private var loadTask: Task<Void, Never>?; private var requestGeneration = 0; private var latestGeneratedAt: Date?; private var failures = 0; private var active = false; private var isInBackground = false
    init(repository: RealActiveSnapshotRepository, cache: ActiveSessionCache, authSession: AuthenticationSession, appState: AppState, clock: AppClock = SystemAppClock()) { self.repository = repository; self.cache = cache; self.authSession = authSession; self.appState = appState; self.clock = clock }
    func start() { guard !active else { return }; active = true; isInBackground = false; loadTask = Task { await loadCacheThenRefresh() }; resumePolling() }
    func stop() { active = false; isInBackground = false; pollingTask?.cancel(); pollingTask = nil; refreshTask?.cancel(); loadTask?.cancel(); loadTask = nil }
    func purge() async { stop(); content = .idle; latestGeneratedAt = nil; failures = 0; await cache.purge() }
    func enterBackground() { isInBackground = true; pollingTask?.cancel(); pollingTask = nil }
    func enterForeground() { guard active else { return }; isInBackground = false; Task { await refresh() }; resumePolling() }
    func loadCacheThenRefresh() async { if let cached = await cache.load() { content = .loadedFromCache(cached); latestGeneratedAt = cached.generatedAt }; await refresh() }
    func refresh() async {
        if let task = refreshTask { await task.value; return }
        requestGeneration += 1; let generation = requestGeneration
        if case .idle = content { content = .loading } else if let visible = visibleSnapshot { content = .refreshing(visible) }
        let task = Task { [repository, authSession, cache] in
            do {
                let snapshot = try await authSession.withAccessTokenReplay { token in
                    try await repository.fetchActiveSnapshot(accessToken: token)
                }
                try Task.checkCancellation()
                let accepted = await MainActor.run { self.apply(snapshot, generation: generation) }
                try Task.checkCancellation()
                if accepted { await cache.save(snapshot) }
            } catch is CancellationError { return }
            catch AuthenticationError.accessTokenExpired { await MainActor.run { self.appState.transition(to: .expired) } }
            catch AuthenticationError.deviceRevoked { await MainActor.run { self.appState.transition(to: .revoked) } }
            catch { await MainActor.run { self.apply(error) } }
        }
        refreshTask = task; await task.value; refreshTask = nil; resumePolling()
    }
    @discardableResult private func apply(_ snapshot: RealActiveSnapshot, generation: Int) -> Bool { guard generation >= requestGeneration else { return false }; if let old = latestGeneratedAt, let new = snapshot.generatedAt, new < old { return false }; latestGeneratedAt = snapshot.generatedAt; failures = 0; content = .loaded(snapshot); return true }
    private func apply(_ error: Error) { failures += 1; let message: String; if let auth = error as? AuthenticationError { message = auth.dashboardMessage } else { message = "Impossible de charger le snapshot." }; if let visible = visibleSnapshot { content = .offline(visible) } else { content = .error(message) } }
    private var visibleSnapshot: RealActiveSnapshot? { switch content { case .loaded(let v), .loadedFromCache(let v), .refreshing(let v?), .stale(let v), .offline(let v?): return v; default: return nil } }
    func resumePolling() { pollingTask?.cancel(); pollingTask = nil; guard active, !isInBackground else { return }; let delay = pollingDelay(); pollingTask = Task { [weak self, clock] in do { try await clock.sleep(seconds: delay); try Task.checkCancellation(); await self?.refresh() } catch is CancellationError { return } catch { return } } }
    func pollingDelay() -> TimeInterval { let base: TimeInterval; switch visibleSnapshot?.activeSession?.lifecycle { case .reconciliationPending: base = 3; case .waitingBuyFill, .waitingSellFill: base = 5; case .waitingBuy, .waitingSell, .positionOpen, .monitoringPosition: base = 10; case .unknown: base = 15; default: base = 30 }; return min(base * pow(2, Double(min(failures, 3))), 60) }
}

private extension AuthenticationError {
    var dashboardMessage: String { switch self { case .notConfigured: return "Botaplata ne peut pas encore joindre son serveur depuis cette version de l'application."; case .offline: return "Connexion momentanément indisponible. Dernier état connu affiché."; case .serverUnavailable: return "Serveur indisponible. Dernier état connu affiché."; case .contractIncompatible, .decodingFailed: return "Réponse du serveur incompatible. Dernier état connu affiché."; default: return userMessage } }
}
