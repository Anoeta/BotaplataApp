import XCTest
@testable import BotaplataApp

@MainActor final class MidnightHistoryLifecycleTests: XCTestCase {
    func testLateEventResponseCannotRepopulateHistoryAfterLogoutPurge() async throws {
        let repository = SuspendedMidnightHistoryRepository()
        let cache = MidnightHistoryMemoryCache()
        let store = try await makeStore(repository: repository, cache: cache)
        let request = Task { await store.refreshTimeline(sessionID: "fixture") }
        await repository.waitUntilStarted()
        await store.purge()
        await repository.finish(page)
        await request.value
        XCTAssertNil(store.timelines["fixture"])
        let saves = await cache.saveCount
        XCTAssertEqual(saves, 0)
    }

    func testLateCacheReadCannotRepopulateHistoryAfterLogoutPurge() async throws {
        let cache = MidnightHistoryMemoryCache(suspendLoad: true)
        let store = try await makeStore(repository: UnconfiguredRealSessionHistoryRepository(), cache: cache)
        let request = Task { await store.loadCache() }
        await cache.waitUntilStarted()
        await store.purge()
        await cache.finishLoad(RealSessionHistoryCached(timelines: ["fixture": page], charts: [:], savedAt: Date()))
        await request.value
        XCTAssertNil(store.timelines["fixture"])
    }

    private var page: TimelinePage {
        TimelinePage(items: PreviewFixtures.timelineEvents, pagination: RealSessionsPagination(page: 1, pageSize: 50, total: 1, hasMore: false), warnings: [], serverTime: PreviewFixtures.now)
    }
    private func makeStore(repository: RealSessionHistoryRepository, cache: RealSessionHistoryCache) async throws -> RealSessionHistoryStore {
        let session = AuthenticationSession(repository: MockAuthenticationRepository(), tokenStore: InMemoryTokenStore())
        try await session.apply(AuthenticationFixtures.successfulSession)
        return RealSessionHistoryStore(repository: repository, cache: cache, authSession: session, appState: AppState.demo())
    }
}

private actor SuspendedMidnightHistoryRepository: RealSessionHistoryRepository {
    private var pending: CheckedContinuation<TimelinePage, Error>?
    private var waiter: CheckedContinuation<Void, Never>?
    func fetchTimeline(sessionID: String, page: Int, pageSize: Int, accessToken: String) async throws -> TimelinePage {
        try await withCheckedThrowingContinuation { pending = $0; waiter?.resume(); waiter = nil }
    }
    func waitUntilStarted() async { if pending == nil { await withCheckedContinuation { waiter = $0 } } }
    func finish(_ page: TimelinePage) { pending?.resume(returning: page); pending = nil }
    func fetchOrders(sessionID: String, page: Int, pageSize: Int, accessToken: String) async throws -> OrdersPage { throw AuthenticationError.notConfigured }
    func fetchDecisions(sessionID: String, page: Int, pageSize: Int, accessToken: String) async throws -> DecisionsPage { throw AuthenticationError.notConfigured }
    func fetchChart(sessionID: String, accessToken: String) async throws -> SessionChart { throw AuthenticationError.notConfigured }
}

private actor MidnightHistoryMemoryCache: RealSessionHistoryCache {
    let suspendLoad: Bool
    var saveCount = 0
    private var pending: CheckedContinuation<RealSessionHistoryCached?, Never>?
    private var waiter: CheckedContinuation<Void, Never>?
    init(suspendLoad: Bool = false) { self.suspendLoad = suspendLoad }
    func load() async -> RealSessionHistoryCached? {
        guard suspendLoad else { return nil }
        return await withCheckedContinuation { pending = $0; waiter?.resume(); waiter = nil }
    }
    func waitUntilStarted() async { if pending == nil { await withCheckedContinuation { waiter = $0 } } }
    func finishLoad(_ cache: RealSessionHistoryCached) { pending?.resume(returning: cache); pending = nil }
    func saveTimeline(sessionID: String, page: TimelinePage) async { saveCount += 1 }
    func saveChart(sessionID: String, chart: SessionChart) async { }
    func purge() async { }
}
