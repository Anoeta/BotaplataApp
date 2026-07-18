import XCTest
@testable import BotaplataApp

actor FakeChartRepository: RealSessionChartRepositoryProtocol {
    private(set) var calls: [(String, TradingChartRange)] = []
    private var results: [TradingChartCacheKey: Result<TradingChart, Error>] = [:]
    private var delay: UInt64 = 0
    func fetchChart(sessionID: String, range: TradingChartRange, before: Date?, limit: Int?, accessToken: String) async throws -> TradingChart {
        calls.append((sessionID, range))
        if delay > 0 { try await Task.sleep(nanoseconds: delay) }
        if let result = results[TradingChartCacheKey(sessionID: sessionID, range: range)] { return try result.get() }
        return Self.chart(sessionID: sessionID, range: range)
    }
    func setResult(_ result: Result<TradingChart, Error>, sessionID: String = "s1", range: TradingChartRange = .sixHours) { results[TradingChartCacheKey(sessionID: sessionID, range: range)] = result }
    func setDelay(_ value: UInt64) { delay = value }
    func callCount() -> Int { calls.count }
    func ranges() -> [TradingChartRange] { calls.map(\.1) }
    static func chart(sessionID: String = "s1", range: TradingChartRange = .sixHours, candles: [TradingCandle]? = nil, warnings: [Warning] = []) -> TradingChart { TradingChart(sessionID: sessionID, symbol: "SOLUSDC", displaySymbol: "SOL/USDC", quoteAsset: "USDC", range: range, timeframe: "1m", generatedAt: Date(timeIntervalSince1970: 10), dataSource: "backend", isComplete: true, hasMore: false, nextBefore: nil, candles: candles ?? [TradingCandle(id: "\(sessionID)-\(range.rawValue)", openTime: Date(timeIntervalSince1970: 0), closeTime: Date(timeIntervalSince1970: 60), isClosed: true, open: 1, high: 2, low: 1, close: 2, volume: nil, vwap: nil, ema200: nil, bollingerUpper: nil, bollingerMiddle: nil, bollingerLower: nil)], markers: [], levels: TradingLevels(entryPrice: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, trailingStopPrice: nil), warnings: warnings) }
}

@MainActor final class RealSessionChartStoreTests: XCTestCase {
    private func store(_ repo: FakeChartRepository, now: @escaping () -> Date = { Date(timeIntervalSince1970: 100) }) -> RealSessionChartStore { RealSessionChartStore(repository: repo, authorize: { work in try await work("token") }, now: now) }
    private func wait() async { try? await Task.sleep(nanoseconds: 80_000_000) }
    func testLoadingIdleToLoaded() async { let repo = FakeChartRepository(); let sut = store(repo); XCTAssertEqual(sut.state, .idle); sut.load(sessionID: "s1"); if case .loading = sut.state {} else { XCTFail() }; await wait(); if case .loaded(let chart) = sut.state { XCTAssertEqual(chart.range, .sixHours) } else { XCTFail("not loaded") } }
    func testValidCacheAvoidsRequest() async { let repo = FakeChartRepository(); let sut = store(repo); sut.seedCache(chart: FakeChartRepository.chart(), fetchedAt: Date(timeIntervalSince1970: 95)); sut.load(sessionID: "s1"); await wait(); XCTAssertEqual(await repo.callCount(), 0); if case .loaded(let chart) = sut.state { XCTAssertEqual(chart.sessionID, "s1") } else { XCTFail() } }
    func testExpiredCacheRefreshesAndReplaces() async { let repo = FakeChartRepository(); let sut = store(repo, now: { Date(timeIntervalSince1970: 500) }); sut.seedCache(chart: FakeChartRepository.chart(), fetchedAt: Date(timeIntervalSince1970: 0)); sut.load(sessionID: "s1"); if case .refreshing = sut.state {} else { XCTFail() }; await wait(); XCTAssertEqual(await repo.callCount(), 1) }
    func testChangingRangeUsesDistinctCacheKey() async { let repo = FakeChartRepository(); let sut = store(repo); sut.seedCache(chart: FakeChartRepository.chart(range: .sixHours), fetchedAt: Date(timeIntervalSince1970: 99)); sut.selectRange(.oneHour, sessionID: "s1"); await wait(); XCTAssertEqual(await repo.ranges(), [.oneHour]); if case .loaded(let chart) = sut.state { XCTAssertEqual(chart.range, .oneHour) } else { XCTFail() } }
    func testRapidTapsOnlyFinalResultApplies() async { let repo = FakeChartRepository(); await repo.setDelay(40_000_000); let sut = store(repo); sut.selectRange(.oneHour, sessionID: "s1"); sut.selectRange(.oneDay, sessionID: "s1"); sut.selectRange(.sevenDays, sessionID: "s1"); await wait(); if case .loaded(let chart) = sut.state { XCTAssertEqual(chart.range, .sevenDays) } else { XCTFail() } }
    func testSingleFlight() async { let repo = FakeChartRepository(); await repo.setDelay(50_000_000); let sut = store(repo); sut.load(sessionID: "s1"); sut.load(sessionID: "s1"); await wait(); XCTAssertEqual(await repo.callCount(), 1) }
    func testOfflineWithCacheAndWithoutCache() async { let repo = FakeChartRepository(); await repo.setResult(.failure(AuthenticationError.offline)); let sut = store(repo, now: { Date(timeIntervalSince1970: 500) }); sut.seedCache(chart: FakeChartRepository.chart(), fetchedAt: Date(timeIntervalSince1970: 0)); sut.refresh(sessionID: "s1"); await wait(); if case .offline = sut.state {} else { XCTFail() }; let empty = store(repo); empty.load(sessionID: "s1"); await wait(); XCTAssertEqual(empty.state, .failed(.networkUnavailable)) }
    func testContractIncompatibleKeepsCache() async { let repo = FakeChartRepository(); await repo.setResult(.failure(AuthenticationError.contractIncompatible)); let sut = store(repo, now: { Date(timeIntervalSince1970: 500) }); sut.seedCache(chart: FakeChartRepository.chart(), fetchedAt: .distantPast); sut.refresh(sessionID: "s1"); await wait(); if case .offline(let chart) = sut.state { XCTAssertEqual(chart.sessionID, "s1") } else { XCTFail() } }
    func testEmptySeriesValidLoadedWithWarning() async { let repo = FakeChartRepository(); let warning = Warning(id: "w", severity: .warning, title: "title", message: "chart_price_series_unavailable"); await repo.setResult(.success(FakeChartRepository.chart(candles: [], warnings: [warning]))); let sut = store(repo); sut.load(sessionID: "s1"); await wait(); if case .loaded(let chart) = sut.state { XCTAssertTrue(chart.candles.isEmpty); XCTAssertEqual(chart.warnings.first?.message, "chart_price_series_unavailable") } else { XCTFail() } }
    func testStopCancelsLateResult() async { let repo = FakeChartRepository(); await repo.setDelay(100_000_000); let sut = store(repo); sut.load(sessionID: "s1"); sut.stop(); await wait(); XCTAssertEqual(sut.state, .loading) }
    func testSessionDifferentCacheNotMixedAndCacheBounded() async { let repo = FakeChartRepository(); let sut = store(repo); for i in 0..<18 { sut.seedCache(chart: FakeChartRepository.chart(sessionID: "s\(i)", range: .sixHours), fetchedAt: Date(timeIntervalSince1970: Double(i))) }; XCTAssertEqual(sut.cacheCount, 16); XCTAssertFalse(sut.hasCache(sessionID: "s0", range: .sixHours)); XCTAssertTrue(sut.hasCache(sessionID: "s17", range: .sixHours)); sut.load(sessionID: "A"); await wait(); XCTAssertFalse(sut.hasCache(sessionID: "B", range: .sixHours)) }
}
