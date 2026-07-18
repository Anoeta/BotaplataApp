import XCTest
@testable import BotaplataApp

final class SessionsPresentationTests: XCTestCase {
    func testFiltersAllActiveHistoryAndWatch() {
        let active = summary(id: "active", lifecycle: .waitingBuy)
        let history = summary(id: "history", lifecycle: .stopped)
        let watch = summary(id: "watch", lifecycle: .waitingBuy, health: .degraded)
        let items = [active, history, watch]
        XCTAssertEqual(SessionsPresentation.filtered(items, filter: .all, query: "").map(\.id), ["active", "history", "watch"])
        XCTAssertEqual(SessionsPresentation.filtered(items, filter: .active, query: "").map(\.id), ["active", "watch"])
        XCTAssertEqual(SessionsPresentation.filtered(items, filter: .history, query: "").map(\.id), ["history"])
        XCTAssertEqual(SessionsPresentation.filtered(items, filter: .watch, query: "").map(\.id), ["watch"])
    }

    func testSearchPairAndStrategyUsesLoadedSummariesOnly() {
        let star = summary(id: "sol", pair: "SOL/USDC", strategy: "Star V3")
        let other = summary(id: "btc", pair: "BTC/USDC", strategy: "Calm")
        XCTAssertEqual(SessionsPresentation.filtered([star, other], filter: .all, query: "sol").map(\.id), ["sol"])
        XCTAssertEqual(SessionsPresentation.filtered([star, other], filter: .all, query: "star").map(\.id), ["sol"])
    }

    func testPositionAbsentWhenQuantityIsNilOrZero() {
        XCTAssertFalse(SessionsPresentation.shouldShowPosition(nil))
        XCTAssertFalse(SessionsPresentation.shouldShowPosition(OpenPosition(pair: "SOL/USDC", quantity: 0, averageExecutionPrice: nil, costBasisPrice: nil)))
        XCTAssertTrue(SessionsPresentation.shouldShowPosition(OpenPosition(pair: "SOL/USDC", quantity: 1, averageExecutionPrice: nil, costBasisPrice: nil)))
    }

    func testFeeAwareNullRowsAreHidden() {
        let rows = SessionsPresentation.feeAwareRows(FeeAwareSummary.empty)
        XCTAssertTrue(rows.isEmpty)
        let complete = SessionsPresentation.feeAwareRows(PreviewFixtures.feeComplete)
        XCTAssertTrue(complete.contains { $0.0 == "Prix de revient frais inclus" })
        XCTAssertFalse(complete.contains { $0.1 == "—" || $0.1 == "Indisponible" })
    }

    func testSubmittedOpenFilledAndReconciliationStayDistinct() {
        XCTAssertEqual(SessionsPresentation.activeOrderStatusText(.submitted), "Envoyé à Kraken")
        XCTAssertEqual(SessionsPresentation.activeOrderStatusText(.open), "En attente sur Kraken")
        XCTAssertEqual(SessionsPresentation.activeOrderStatusText(.filled), "Confirmé par Kraken")
        XCTAssertEqual(SessionsPresentation.activeOrderStatusText(.reconciliationRequired), "Vérification en cours")
        XCTAssertNotEqual(SessionsPresentation.activeOrderStatusText(.reconciliationRequired), SessionsPresentation.activeOrderStatusText(.rejected))
    }

    func testNavigationRoutePreservesSection() {
        XCTAssertEqual(SessionRoute.detail(id: "s1", section: .chart), SessionRoute.detail(id: "s1", section: .chart))
        XCTAssertNotEqual(SessionRoute.detail(id: "s1", section: .chart), SessionRoute.detail(id: "s1", section: .orders))
    }

    private func summary(id: String, pair: String = "SOL/USDC", lifecycle: SessionLifecycleState = .waitingBuy, health: RuntimeHealthState = .healthy, strategy: String? = nil) -> SessionSummary {
        SessionSummary(id: id, pair: pair, provider: .kraken, lifecycle: lifecycle, runtimeHealth: health, freshness: DataFreshness(status: .fresh, updatedAt: nil, source: .backend), executionMode: .spotProduction, strategyName: strategy)
    }
}
