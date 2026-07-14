import Foundation
import XCTest
@testable import BotaplataApp

@MainActor
final class ActiveSessionStoreTests: XCTestCase {
    func testStartIsIdempotentAndRunsOneInitialLoadRefreshAndPollingLoop() async {
        let harness = await Harness(cached: snapshot("cache", at: 10))
        await harness.repo.enqueue(.success(snapshot("network", at: 11)))
        harness.store.start(); harness.store.start(); harness.store.start()
        await harness.repo.waitForCalls(1)
        await harness.repo.finishNext()
        await harness.clock.waitForSleepCount(2)
        XCTAssertEqual(await harness.cache.loadCount, 1)
        XCTAssertEqual(await harness.repo.callCount, 1)
        XCTAssertEqual(await harness.clock.sleepCount, 2)
        harness.store.stop()
    }

    func testCachedSnapshotIsDisplayedImmediatelyWhileNetworkIsSuspendedThenNetworkWins() async {
        let cached = snapshot("A", at: 10), fresh = snapshot("B", at: 20)
        let harness = await Harness(cached: cached)
        await harness.repo.enqueue(.success(fresh))
        harness.store.start()
        await harness.repo.waitForCalls(1)
        XCTAssertLoadedFromCache(harness.store.content, cached)
        await harness.repo.finishNext()
        await eventually { if case .loaded(fresh) = harness.store.content { return true }; return false }
        harness.store.stop()
    }

    func testRefreshKeepsVisibleContentAsRefreshingWhileRequestIsSuspended() async {
        let old = snapshot("old", at: 10), new = snapshot("new", at: 20)
        let harness = await Harness()
        await harness.repo.enqueue(.success(old)); await runRefresh(harness)
        await eventually { if case .loaded(old) = harness.store.content { return true }; return false }
        await harness.repo.enqueue(.success(new))
        let task = Task { await harness.store.refresh() }
        await harness.repo.waitForCalls(2)
        XCTAssertRefreshing(harness.store.content, old)
        await harness.repo.finishNext(); await task.value
        harness.store.stop()
    }

    func testRefreshIsSingleFlightForConcurrentCallers() async {
        let harness = await Harness()
        await harness.repo.enqueue(.success(snapshot("one", at: 1)))
        async let first: Void = harness.store.refresh()
        async let second: Void = harness.store.refresh()
        async let third: Void = harness.store.refresh()
        await harness.repo.waitForCalls(1)
        XCTAssertEqual(await harness.repo.callCount, 1)
        await harness.repo.finishNext()
        _ = await (first, second, third)
        XCTAssertEqual(await harness.repo.callCount, 1)
        harness.store.stop()
    }

    func testStopCancelsPollingSoReleasedClockDoesNotTriggerAnotherRefresh() async {
        let harness = await Harness()
        await harness.repo.enqueue(.success(snapshot("initial", at: 1)))
        harness.store.start(); await harness.repo.waitForCalls(1); await harness.repo.finishNext()
        await harness.clock.waitForSleepCount(2)
        harness.store.stop()
        await harness.clock.resumeAll()
        await shortYield()
        XCTAssertEqual(await harness.repo.callCount, 1)
    }

    func testEnterBackgroundCancelsPollingAndKeepsVisibleSnapshot() async {
        let visible = snapshot("visible", at: 1)
        let harness = await Harness()
        await harness.repo.enqueue(.success(visible))
        harness.store.start(); await harness.repo.waitForCalls(1); await harness.repo.finishNext()
        await harness.clock.waitForSleepCount(2)
        harness.store.enterBackground()
        await harness.clock.resumeAll(); await shortYield()
        XCTAssertEqual(await harness.repo.callCount, 1)
        XCTAssertVisible(harness.store.content, visible)
        harness.store.stop()
    }

    func testEnterForegroundRefreshesAndResumesOnePollingLoopOnlyWhenStarted() async {
        let harness = await Harness()
        harness.store.enterForeground(); await shortYield()
        XCTAssertEqual(await harness.repo.callCount, 0)

        await harness.repo.enqueue(.success(snapshot("start", at: 1)))
        harness.store.start(); await harness.repo.waitForCalls(1); await harness.repo.finishNext()
        harness.store.enterBackground()
        await harness.repo.enqueue(.success(snapshot("foreground", at: 2)))
        harness.store.enterForeground(); await harness.repo.waitForCalls(2); await harness.repo.finishNext()
        await harness.clock.waitForSleepCount(3)
        XCTAssertEqual(await harness.repo.callCount, 2)
        harness.store.stop()
    }

    func testPollingDelaysAndBackoffAreDeterministic() async {
        let harness = await Harness()
        let cases: [(SessionLifecycleState?, TimeInterval)] = [(.reconciliationPending, 3), (.waitingBuyFill, 5), (.waitingSellFill, 5), (.waitingBuy, 10), (.waitingSell, 10), (.positionOpen, 10), (.monitoringPosition, 10), (.unknown, 15), (nil, 30)]
        for (life, delay) in cases {
            await harness.repo.enqueue(.success(snapshot("\(delay)", at: delay, lifecycle: life)))
            await runRefresh(harness)
            XCTAssertEqual(harness.store.pollingDelay(), delay)
        }
        await harness.repo.enqueue(.failure(AuthenticationError.serverUnavailable)); await runRefresh(harness)
        XCTAssertEqual(harness.store.pollingDelay(), 60) // no active session base 30 * 2
        for _ in 0..<5 { await harness.repo.enqueue(.failure(AuthenticationError.serverUnavailable)); await runRefresh(harness) }
        XCTAssertEqual(harness.store.pollingDelay(), 60)
        harness.store.stop()
    }

    func testCancellationErrorDoesNotBecomeUIErrorOrOffline() async {
        let visible = snapshot("visible", at: 1)
        let harness = await Harness()
        await harness.repo.enqueue(.success(visible)); await runRefresh(harness)
        await harness.repo.enqueue(.failure(CancellationError()))
        await runRefresh(harness)
        XCTAssertVisible(harness.store.content, visible)
        XCTAssertEqual(harness.store.pollingDelay(), 30)
        harness.store.stop()
    }

    func testOlderSnapshotIsRejectedAndNotSavedToCache() async {
        let newer = snapshot("newer", at: 10), older = snapshot("older", at: 5)
        let harness = await Harness()
        await harness.repo.enqueue(.success(newer)); await runRefresh(harness)
        XCTAssertEqual(await harness.cache.saveCount, 1)
        await harness.repo.enqueue(.success(older)); await runRefresh(harness)
        XCTAssertVisible(harness.store.content, newer)
        XCTAssertEqual(await harness.cache.saveCount, 1)
        harness.store.stop()
    }

    func testOfflineWithVisibleContentKeepsSnapshotAndOfflineWithoutContentShowsError() async {
        let visible = snapshot("visible", at: 1)
        let withCache = await Harness()
        await withCache.repo.enqueue(.success(visible)); await runRefresh(withCache)
        await withCache.repo.enqueue(.failure(AuthenticationError.offline)); await runRefresh(withCache)
        if case .offline(let snap?) = withCache.store.content { XCTAssertEqual(snap, visible) } else { XCTFail("Expected offline with visible snapshot") }
        withCache.store.stop()

        let empty = await Harness()
        await empty.repo.enqueue(.failure(AuthenticationError.serverUnavailable)); await runRefresh(empty)
        if case .error(let message) = empty.store.content { XCTAssertFalse(message.isEmpty) } else { XCTFail("Expected error without visible snapshot") }
        empty.store.stop()
    }

    func testAccessTokenExpiredRefreshesAuthAndReplaysExactlyOnceWithNewBearer() async {
        let harness = await Harness(accessToken: "old", refreshToken: "refresh")
        await harness.repo.enqueue(.failure(AuthenticationError.accessTokenExpired))
        await harness.repo.enqueue(.success(snapshot("ok", at: 1)))
        await harness.authRepo.enqueueRefresh(.success(session(access: "new", refresh: "refresh2")))
        let task = Task { await harness.store.refresh() }
        await harness.repo.waitForCalls(1)
        await harness.repo.finishNext()
        await harness.repo.waitForCalls(2)
        await harness.repo.finishNext()
        await task.value
        XCTAssertEqual(await harness.repo.callCount, 2)
        XCTAssertEqual(await harness.repo.tokens, ["old", "new"])
        XCTAssertEqual(await harness.authRepo.refreshCount, 1)
        harness.store.stop()
    }

    func testSecondAccessTokenExpiredExpiresAppWithoutLooping() async {
        let harness = await Harness(accessToken: "old", refreshToken: "refresh")
        await harness.repo.enqueue(.failure(AuthenticationError.accessTokenExpired)); await harness.repo.enqueue(.failure(AuthenticationError.accessTokenExpired))
        await harness.authRepo.enqueueRefresh(.success(session(access: "new", refresh: "refresh2")))
        let task = Task { await harness.store.refresh() }
        await harness.repo.waitForCalls(1)
        await harness.repo.finishNext()
        await harness.repo.waitForCalls(2)
        await harness.repo.finishNext()
        await task.value
        XCTAssertEqual(await harness.repo.callCount, 2)
        XCTAssertEqual(await harness.authRepo.refreshCount, 1)
        XCTAssertEqual(harness.appState.sessionState, .expired)
        harness.store.stop()
    }

    func testDeviceRevokedTransitionsWithoutAuthRefresh() async {
        let harness = await Harness(accessToken: "token", refreshToken: "refresh")
        await harness.repo.enqueue(.failure(AuthenticationError.deviceRevoked))
        await runRefresh(harness)
        XCTAssertEqual(harness.appState.sessionState, .revoked)
        XCTAssertEqual(await harness.authRepo.refreshCount, 0)
        harness.store.stop()
    }

    func testPurgeClearsContentPurgesCacheStopsPollingAndCancelsRefresh() async {
        let harness = await Harness(cached: snapshot("cached", at: 1))
        await harness.repo.enqueue(.success(snapshot("slow", at: 2)))
        harness.store.start(); await harness.repo.waitForCalls(1)
        await harness.store.purge()
        await harness.repo.finishNext(); await harness.clock.resumeAll(); await shortYield()
        if case .idle = harness.store.content {} else { XCTFail("Expected idle after purge") }
        XCTAssertEqual(await harness.cache.purgeCount, 1)
        XCTAssertEqual(await harness.cache.saveCount, 0)
        XCTAssertEqual(await harness.repo.callCount, 1)
    }

    func testStopDuringRefreshCancelsWithoutUserErrorCacheSaveOrPollingResume() async {
        let harness = await Harness()
        await harness.repo.enqueue(.success(snapshot("late", at: 1)))
        let task = Task { await harness.store.refresh() }
        await harness.repo.waitForCalls(1)
        harness.store.stop()
        await harness.repo.finishNext(); await task.value; await shortYield()
        if case .loading = harness.store.content {} else { XCTFail("Expected no artificial user error") }
        XCTAssertEqual(await harness.cache.saveCount, 0)
        XCTAssertEqual(await harness.clock.sleepCount, 0)
    }
}

@MainActor
private func runRefresh(_ harness: Harness) async {
    let target = await harness.repo.callCount + 1
    let task = Task { await harness.store.refresh() }
    await harness.repo.waitForCalls(target)
    await harness.repo.finishNext()
    await task.value
}

private func shortYield() async { for _ in 0..<5 { await Task.yield() } }

@MainActor
private func eventually(_ predicate: @escaping @MainActor () -> Bool) async {
    for _ in 0..<50 { if predicate() { return }; await Task.yield() }
}

@MainActor private func XCTAssertLoadedFromCache(_ content: LoadedContent<RealActiveSnapshot>, _ expected: RealActiveSnapshot, file: StaticString = #filePath, line: UInt = #line) { if case .loadedFromCache(expected) = content {} else { XCTFail("Expected loadedFromCache", file: file, line: line) } }
@MainActor private func XCTAssertRefreshing(_ content: LoadedContent<RealActiveSnapshot>, _ expected: RealActiveSnapshot, file: StaticString = #filePath, line: UInt = #line) { if case .refreshing(let snap?) = content { XCTAssertEqual(snap, expected, file: file, line: line) } else { XCTFail("Expected refreshing", file: file, line: line) } }
@MainActor private func XCTAssertVisible(_ content: LoadedContent<RealActiveSnapshot>, _ expected: RealActiveSnapshot, file: StaticString = #filePath, line: UInt = #line) { switch content { case .loaded(expected), .loadedFromCache(expected), .refreshing(expected?), .offline(expected?): break; default: XCTFail("Expected visible snapshot", file: file, line: line) } }

private func snapshot(_ id: String, at seconds: TimeInterval, lifecycle: SessionLifecycleState? = nil) -> RealActiveSnapshot {
    RealActiveSnapshot(generatedAt: Date(timeIntervalSince1970: seconds), activeSessionCount: lifecycle == nil ? 0 : 1, activeSession: lifecycle.map { sessionDetail(id: id, lifecycle: $0) }, warnings: [Warning(id: id, severity: .information, title: id, message: id)], requestID: id, serverTime: Date(timeIntervalSince1970: seconds))
}

private func sessionDetail(id: String, lifecycle: SessionLifecycleState) -> SessionDetail {
    SessionDetail(id: id, pair: "SOL/USDC", provider: .kraken, lifecycle: lifecycle, runtimeHealth: .healthy, freshness: DataFreshness(status: .fresh, updatedAt: nil, source: .backend), currentPrice: nil, position: nil, decision: StrategyDecisionSummary(title: "t", detail: "d", favorableConditions: nil, requiredConditions: nil), activeOrder: nil, pnl: nil, feeAware: FeeAwareSummary(executionPrice: nil, costBasisPrice: nil, buyFeeQuote: nil, buyFeeRateEffective: nil, estimatedSellFeeQuote: nil, estimatedSellFeeRate: nil, estimatedSellFeeSource: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, minimumNetProfitRate: nil, estimatedSlippageRate: nil, unrealizedPnLGrossQuote: nil, unrealizedPnLNetEstimatedQuote: nil, realizedPnLNetQuote: nil, totalEstimatedCycleFeesQuote: nil, liquidityRole: nil), warnings: [])
}

private func session(access: String, refresh: String) -> AuthenticatedSession {
    AuthenticatedSession(accessToken: access, accessTokenExpiresAt: .distantFuture, refreshToken: refresh, refreshTokenExpiresAt: .distantFuture, tokenType: "Bearer", user: AuthenticatedUser(id: "u", displayName: "User", roles: [], permissions: []), deviceID: "device")
}

@MainActor
private struct Harness {
    let repo: ControlledRealActiveSnapshotRepository
    let cache: MemoryActiveSessionCache
    let authRepo: ControlledAuthenticationRepository
    let tokenStore: InMemoryTokenStore
    let authSession: AuthenticationSession
    let appState: AppState
    let clock: ControlledAppClock
    let store: ActiveSessionStore
    init(cached: RealActiveSnapshot? = nil, accessToken: String? = "token", refreshToken: String = "refresh") async {
        repo = ControlledRealActiveSnapshotRepository(); cache = MemoryActiveSessionCache(cached: cached); authRepo = ControlledAuthenticationRepository(); tokenStore = InMemoryTokenStore(); authSession = AuthenticationSession(repository: authRepo, tokenStore: tokenStore); appState = AppState(sessionState: .authenticated); clock = ControlledAppClock()
        if let accessToken { try? await authSession.apply(session(access: accessToken, refresh: refreshToken)) } else { await tokenStore.saveRefreshToken(refreshToken) }
        store = ActiveSessionStore(repository: repo, cache: cache, authSession: authSession, appState: appState, clock: clock)
    }
}

private actor MemoryActiveSessionCache: ActiveSessionCache {
    private var cached: RealActiveSnapshot?
    private(set) var loadCount = 0, saveCount = 0, purgeCount = 0
    private(set) var lastSaved: RealActiveSnapshot?
    init(cached: RealActiveSnapshot?) { self.cached = cached }
    func load() async -> RealActiveSnapshot? { loadCount += 1; return cached }
    func save(_ snapshot: RealActiveSnapshot) async { saveCount += 1; lastSaved = snapshot; cached = snapshot }
    func purge() async { purgeCount += 1; cached = nil }
}

private actor ControlledRealActiveSnapshotRepository: RealActiveSnapshotRepository {
    enum Outcome { case success(RealActiveSnapshot), failure(Error) }
    private var outcomes: [Outcome] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var callWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var callCount = 0
    private(set) var tokens: [String] = []
    func enqueue(_ outcome: Outcome) { outcomes.append(outcome) }
    func fetchActiveSnapshot(accessToken: String) async throws -> RealActiveSnapshot {
        callCount += 1; tokens.append(accessToken); signalCallWaiters()
        await withCheckedContinuation { waiters.append($0) }
        let outcome = outcomes.isEmpty ? .failure(AuthenticationError.serverUnavailable) : outcomes.removeFirst()
        switch outcome { case .success(let s): return s; case .failure(let e): throw e }
    }
    func finishNext() { if !waiters.isEmpty { waiters.removeFirst().resume() } }
    func waitForCalls(_ count: Int) async { if callCount >= count { return }; await withCheckedContinuation { callWaiters.append((count, $0)) } }
    private func signalCallWaiters() { let ready = callWaiters.filter { callCount >= $0.0 }; callWaiters.removeAll { callCount >= $0.0 }; ready.forEach { $0.1.resume() } }
}

private actor ControlledAuthenticationRepository: AuthenticationRepository {
    enum Outcome { case success(AuthenticatedSession), failure(Error) }
    private var refreshOutcomes: [Outcome] = []
    private(set) var refreshCount = 0
    func enqueueRefresh(_ outcome: Outcome) { refreshOutcomes.append(outcome) }
    func refresh(refreshToken: String, installationID: String) async throws -> AuthenticatedSession { refreshCount += 1; let outcome = refreshOutcomes.isEmpty ? .failure(AuthenticationError.refreshRevoked) : refreshOutcomes.removeFirst(); switch outcome { case .success(let s): return s; case .failure(let e): throw e } }
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge { throw AuthenticationError.notConfigured }
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession { throw AuthenticationError.notConfigured }
    func logout(accessToken: String?) async {}
    func authorizedDevices(accessToken: String) async throws -> [AuthorizedDevice] { [] }
    func revokeDevice(id: String, accessToken: String) async throws -> DeviceRevocationResult { DeviceRevocationResult(revokedDeviceID: id, currentDeviceRevoked: false) }
}

private actor ControlledAppClock: AppClock {
    private var continuations: [CancellationContinuationBox] = []
    private var sleepWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private(set) var requestedSeconds: [TimeInterval] = []
    var sleepCount: Int { requestedSeconds.count }
    func sleep(seconds: TimeInterval) async throws {
        requestedSeconds.append(seconds); signalSleepWaiters()
        let box = CancellationContinuationBox()
        try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                box.store(continuation)
                continuations.append(box)
            }
        }, onCancel: {
            box.cancel()
        })
    }
    func resumeAll() { continuations.forEach { $0.resume() }; continuations.removeAll() }
    func waitForSleepCount(_ count: Int) async { if requestedSeconds.count >= count { return }; await withCheckedContinuation { sleepWaiters.append((count, $0)) } }
    private func signalSleepWaiters() { let ready = sleepWaiters.filter { requestedSeconds.count >= $0.0 }; sleepWaiters.removeAll { requestedSeconds.count >= $0.0 }; ready.forEach { $0.1.resume() } }
}

private final class CancellationContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var cancelled = false

    func store(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if cancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(throwing: CancellationError())
    }

    func resume() {
        lock.lock()
        let continuation = continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}
