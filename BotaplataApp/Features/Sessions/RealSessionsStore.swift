import Foundation
import Observation

@MainActor @Observable final class RealSessionsStore {
    var content: LoadedContent<[SessionSummary]> = .idle
    var pagination: RealSessionsPagination?; var warnings: [Warning] = []; var details: [String: LoadedContent<SessionDetail>] = [:]
    private let repository: RealSessionsRepository; private let cache: RealSessionsCache; private let authSession: AuthenticationSession; private let appState: AppState; private let pageSize: Int
    private var refreshTask: Task<Void, Never>?; private var nextTask: Task<Void, Never>?; private var detailTasks: [String: Task<Void, Never>] = [:]; private var generation = 0; private var detailGenerations: [String: Int] = [:]
    init(repository: RealSessionsRepository, cache: RealSessionsCache, authSession: AuthenticationSession, appState: AppState, pageSize: Int = 25) { self.repository = repository; self.cache = cache; self.authSession = authSession; self.appState = appState; self.pageSize = pageSize }
    func start() { Task { await loadCacheThenRefresh() } }
    func purge() async { refreshTask?.cancel(); nextTask?.cancel(); detailTasks.values.forEach { $0.cancel() }; content = .idle; pagination = nil; warnings = []; details = [:]; await cache.purge() }
    func loadCacheThenRefresh() async { if let c = await cache.load() { content = .loadedFromCache(c.items); pagination = c.pagination }; await refresh() }
    func refresh() async { if let task = refreshTask { await task.value; return }; generation += 1; let g = generation; if case .idle = content { content = .loading } else { content = .refreshing(visibleItems) }
        let task = Task { [repository, authSession, cache, pageSize] in do { let page = try await Self.authorized(authSession: authSession) { try await repository.fetchSessions(page: 1, pageSize: pageSize, accessToken: $0) }; try Task.checkCancellation(); let accepted = await MainActor.run { self.apply(page, append: false, generation: g) }; if accepted { await cache.save(RealSessionsCachedPage(items: page.items, pagination: page.pagination, savedAt: Date())) } } catch is CancellationError {} catch AuthenticationError.accessTokenExpired { await MainActor.run {
                self.appState.transition(to: .expired)
                return
            } } catch AuthenticationError.deviceRevoked { await MainActor.run {
                self.appState.transition(to: .revoked)
                return
            } } catch { await MainActor.run { self.applyListError(error) } } }
        refreshTask = task; await task.value; refreshTask = nil }
    func loadNextPageIfNeeded(currentItemID: String? = nil) async { guard nextTask == nil, pagination?.hasMore == true, let p = pagination else { return }; if let id = currentItemID, !visibleItems.suffix(5).contains(where: { $0.id == id }) { return }; let next = p.page + 1; let g = generation
        let task = Task { [repository, authSession, pageSize] in do { let page = try await Self.authorized(authSession: authSession) { try await repository.fetchSessions(page: next, pageSize: pageSize, accessToken: $0) }; try Task.checkCancellation(); await MainActor.run {
                    _ = self.apply(page, append: true, generation: g)
                } } catch is CancellationError {} catch AuthenticationError.accessTokenExpired { await MainActor.run {
                self.appState.transition(to: .expired)
                return
            } } catch AuthenticationError.deviceRevoked { await MainActor.run {
                self.appState.transition(to: .revoked)
                return
            } } catch { await MainActor.run { self.content = .partial(self.visibleItems) } } }
        nextTask = task; await task.value; nextTask = nil }
    func loadDetail(id: String) async { if let t = detailTasks[id] { await t.value; return }; let existing = visibleDetail(id); details[id] = existing.map { .refreshing($0) } ?? .loading; detailGenerations[id, default: 0] += 1; let g = detailGenerations[id]!
        let task = Task { [repository, authSession] in do { let detail = try await Self.authorized(authSession: authSession) { try await repository.fetchSessionDetail(id: id, accessToken: $0) }; try Task.checkCancellation(); await MainActor.run { if self.detailGenerations[id] == g { self.details[id] = .loaded(detail) } } } catch is CancellationError {} catch AuthenticationError.accessTokenExpired { await MainActor.run {
                self.appState.transition(to: .expired)
                return
            } } catch AuthenticationError.deviceRevoked { await MainActor.run {
                self.appState.transition(to: .revoked)
                return
            } } catch { await MainActor.run { if let existing { self.details[id] = .offline(existing) } else { self.details[id] = .error("Impossible de charger cette session.") } } } }
        detailTasks[id] = task; await task.value; detailTasks[id] = nil }
    @discardableResult private func apply(_ page: RealSessionsPage, append: Bool, generation g: Int) -> Bool { guard g >= generation else { return false }; warnings = page.warnings; pagination = page.pagination; var merged = append ? visibleItems : []; var ids = Set(merged.map(\.id)); for item in page.items where !ids.contains(item.id) { merged.append(item); ids.insert(item.id) }; content = .loaded(merged); return true }
    private func applyListError(_ error: Error) { if visibleItems.isEmpty { content = .error("Impossible de charger les sessions") } else { content = .offline(visibleItems) } }
    var visibleItems: [SessionSummary] { switch content { case .loaded(let v), .loadedFromCache(let v), .refreshing(let v?), .partial(let v), .stale(let v), .offline(let v?): return v; default: return [] } }
    func visibleDetail(_ id: String) -> SessionDetail? { switch details[id] { case .loaded(let v), .loadedFromCache(let v), .refreshing(let v?), .offline(let v?), .stale(let v): return v; default: return nil } }
    private static func authorized<T: Sendable>(authSession: AuthenticationSession, operation: @escaping @Sendable (String) async throws -> T) async throws -> T { try await authSession.withAccessTokenReplay(operation) }
}
