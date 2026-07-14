import Foundation
import Observation

@MainActor
@Observable
final class ActiveSessionStore {
    var content: LoadedContent<RealActiveSnapshot> = .idle
    private let repository: RealActiveSnapshotRepository; private let cache: ActiveSessionCache; private let authSession: AuthenticationSession; private let appState: AppState
    private var refreshTask: Task<Void, Never>?; private var pollingTask: Task<Void, Never>?; private var requestGeneration = 0; private var latestGeneratedAt: Date?; private var failures = 0; private var active = false
    init(repository: RealActiveSnapshotRepository, cache: ActiveSessionCache, authSession: AuthenticationSession, appState: AppState) { self.repository = repository; self.cache = cache; self.authSession = authSession; self.appState = appState }
    func start() { guard !active else { return }; active = true; Task { await loadCacheThenRefresh() }; resumePolling() }
    func stop() { active = false; pollingTask?.cancel(); refreshTask?.cancel() }
    func purge() async { stop(); content = .idle; await cache.purge() }
    func enterBackground() { pollingTask?.cancel() }
    func enterForeground() { guard active else { return }; Task { await refresh() }; resumePolling() }
    func loadCacheThenRefresh() async { if let cached = await cache.load() { content = .loadedFromCache(cached); latestGeneratedAt = cached.generatedAt }; await refresh() }
    func refresh() async { if refreshTask != nil { return }; requestGeneration += 1; let generation = requestGeneration; if case .idle = content { content = .loading } else if let visible = visibleSnapshot { content = .refreshing(visible) }
        let task = Task { [repository, authSession, cache] in
            do {
                let token = try await authSession.validAccessTokenRefreshingIfNeeded()
                let snapshot: RealActiveSnapshot
                do { snapshot = try await repository.fetchActiveSnapshot(accessToken: token) }
                catch AuthenticationError.accessTokenExpired {
                    let refreshed = try await authSession.refresh()
                    snapshot = try await repository.fetchActiveSnapshot(accessToken: refreshed.accessToken)
                }
                await MainActor.run { self.apply(snapshot, generation: generation) }
                await cache.save(snapshot)
            }
            catch AuthenticationError.accessTokenExpired { await MainActor.run { self.appState.transition(to: .expired) } }
            catch AuthenticationError.deviceRevoked { await MainActor.run { self.appState.transition(to: .revoked) } }
            catch { await MainActor.run { self.apply(error) } }
        }
        refreshTask = task; await task.value; refreshTask = nil; resumePolling() }
    private func apply(_ snapshot: RealActiveSnapshot, generation: Int) { guard generation >= requestGeneration else { return }; if let old = latestGeneratedAt, let new = snapshot.generatedAt, new < old { return }; latestGeneratedAt = snapshot.generatedAt; failures = 0; content = .loaded(snapshot) }
    private func apply(_ error: Error) { failures += 1; if let visible = visibleSnapshot { content = .offline(visible) } else { content = .error((error as? AuthenticationError)?.userMessage ?? "Impossible de charger le snapshot.") } }
    private var visibleSnapshot: RealActiveSnapshot? { switch content { case .loaded(let v), .loadedFromCache(let v), .refreshing(let v?), .stale(let v), .offline(let v?): return v; default: return nil } }
    private func resumePolling() { pollingTask?.cancel(); guard active else { return }; let delay = pollingDelay(); pollingTask = Task { [weak self] in try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)); await self?.refresh() } }
    func pollingDelay() -> TimeInterval { let base: TimeInterval; switch visibleSnapshot?.activeSession?.lifecycle { case .reconciliationPending: base = 3; case .waitingBuyFill, .waitingSellFill: base = 5; case .waitingBuy, .waitingSell, .positionOpen, .monitoringPosition: base = 10; case .unknown: base = 15; default: base = 30 }; return min(base * pow(2, Double(min(failures, 3))), 60) }
}
