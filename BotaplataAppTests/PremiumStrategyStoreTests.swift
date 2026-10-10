import XCTest
@testable import BotaplataApp

private actor ControlledStrategyRepository: RealStrategyExplanationRepository {
    private var pending: [String: CheckedContinuation<StrategyExplanation, Error>] = [:]
    private var calls = 0
    func fetchStrategyExplanation(sessionID: String, accessToken: String) async throws -> StrategyExplanation {
        calls += 1
        return try await withCheckedThrowingContinuation { pending[sessionID] = $0 }
    }
    func hasRequest(_ id: String) -> Bool { pending[id] != nil }
    func count() -> Int { calls }
    func finish(_ id: String, result: Result<StrategyExplanation, Error>) { pending.removeValue(forKey: id)?.resume(with: result) }
}

@MainActor final class PremiumStrategyStoreTests: XCTestCase {
    private func explanation(_ id: String) throws -> StrategyExplanation {
        let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/MobileV1/StrategyExplanation/backend_rsi_43.json")
        let source = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(contentsOf: path)).mapped()
        return StrategyExplanation(sessionID: id, strategy: source.strategy, decision: source.decision, score: source.score, analysis: source.analysis, market: source.market, conditions: source.conditions, blockers: source.blockers, indicators: source.indicators, positionProtection: source.positionProtection, warnings: source.warnings, meta: source.meta)
    }
    private func store(_ repo: ControlledStrategyRepository) -> RealStrategyExplanationStore {
        RealStrategyExplanationStore(repository: repo, authorize: { work in try await work("test-only-token") })
    }
    private func waitForRequest(_ id: String, repo: ControlledStrategyRepository) async throws {
        for _ in 0..<200 {
            if await repo.hasRequest(id) { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw NSError(domain: "Missing test request", code: 1)
    }

    func testSwitchingSessionIgnoresLateResponseAndClearsPreviousAnalysis() async throws {
        let repo = ControlledStrategyRepository(); let sut = store(repo)
        let first = Task { await sut.load(sessionID: "a") }
        try await waitForRequest("a", repo: repo)
        let second = Task { await sut.load(sessionID: "b") }
        try await waitForRequest("b", repo: repo)
        XCTAssertNil(sut.explanation)
        await repo.finish("b", result: .success(try explanation("b")))
        await second.value
        await repo.finish("a", result: .success(try explanation("a")))
        await first.value
        XCTAssertEqual(sut.explanation?.sessionID, "b")
    }
    func testPurgeRejectsLateResponseAfterLogout() async throws {
        let repo = ControlledStrategyRepository(); let sut = store(repo)
        let task = Task { await sut.load(sessionID: "a") }
        try await waitForRequest("a", repo: repo)
        sut.purge()
        await repo.finish("a", result: .success(try explanation("a")))
        await task.value
        XCTAssertNil(sut.explanation)
        XCTAssertNil(sut.lastUpdatedAt)
        XCTAssertNil(sut.sessionID)
    }
    func testCacheDoesNotAdvanceReceivedDateOrRepeatRequest() async throws {
        let repo = ControlledStrategyRepository(); let sut = store(repo)
        let task = Task { await sut.load(sessionID: "a") }
        try await waitForRequest("a", repo: repo)
        await repo.finish("a", result: .success(try explanation("a")))
        await task.value
        let original = sut.lastUpdatedAt
        await sut.load(sessionID: "a")
        let count = await repo.count()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(sut.lastUpdatedAt, original)
    }
    func testOfflineKeepsCachedAnalysisWithOriginalDate() async throws {
        let repo = ControlledStrategyRepository(); let sut = store(repo)
        let first = Task { await sut.load(sessionID: "a") }
        try await waitForRequest("a", repo: repo)
        await repo.finish("a", result: .success(try explanation("a"))); await first.value
        let original = sut.lastUpdatedAt
        let refresh = Task { await sut.refresh(sessionID: "a") }
        try await waitForRequest("a", repo: repo)
        await repo.finish("a", result: .failure(AuthenticationError.offline)); await refresh.value
        XCTAssertTrue(sut.isOffline)
        XCTAssertEqual(sut.explanation?.sessionID, "a")
        XCTAssertEqual(sut.lastUpdatedAt, original)
        if case .offlineCached = sut.state {} else { XCTFail("Expected cached offline state") }
    }
    func testMismatchedBackendSessionIsRejected() async throws {
        let repo = ControlledStrategyRepository(); let sut = store(repo)
        let task = Task { await sut.load(sessionID: "a") }
        try await waitForRequest("a", repo: repo)
        await repo.finish("a", result: .success(try explanation("wrong"))); await task.value
        XCTAssertNil(sut.explanation)
        if case .error = sut.state {} else { XCTFail("Expected incompatible contract error") }
    }
}
