import XCTest
@testable import BotaplataApp

final class MidnightPresentationTests: XCTestCase {
    func testNavigationHasFiveStableDestinations() {
        XCTAssertEqual(AppTab.allCases, [.dashboard, .sessions, .analysis, .journal, .profile])
        XCTAssertEqual(AppTab.allCases.map(\.title), ["Accueil", "Sessions", "Analyse", "Journal", "Profil"])
    }

    func testStoppedTimestampOverridesRunningLifecycle() {
        XCTAssertTrue(SessionArchivePresentation.isHistorical(lifecycle: .waitingBuy, status: "running", stoppedAt: Date(timeIntervalSince1970: 1)))
    }

    func testArchiveIsHistoricalEvenWithAnOldActiveLifecycle() {
        XCTAssertTrue(SessionArchivePresentation.isHistorical(lifecycle: .positionOpen, status: "archived", stoppedAt: nil))
        XCTAssertFalse(SessionArchivePresentation.isHistorical(lifecycle: .waitingBuy, status: "running", stoppedAt: nil))
    }

    func testPersistedStrategyVersionSurvivesSummaryMapping() throws {
        let dto = try JSONDecoder().decode(RealSessionSummaryDTO.self, from: Data(#"{"id":"28","display_symbol":"SOL/USDC","status":"stopped","lifecycle_state":"waiting_buy","strategy":{"key":"star_v3","version":"3.1","display_name":"Star V3"}}"#.utf8))
        let session = dto.mapped()
        XCTAssertEqual(session.strategyVersion, "3.1")
        XCTAssertTrue(session.isHistorical)
        XCTAssertEqual(SessionArchivePresentation.strategy(name: session.strategyName, version: session.strategyVersion), "Star V3 · 3.1")
    }

    func testPersistedStrategyVersionSurvivesDetailMapping() throws {
        let dto = try JSONDecoder().decode(RealSessionDetailDTO.self, from: Data(#"{"id":"28","display_symbol":"SOL/USDC","status":"archived","lifecycle_state":"position_open","strategy_display_name":"Star V3.2","strategy_version":"3.2"}"#.utf8))
        let session = dto.mapped()
        XCTAssertEqual(session.strategyVersion, "3.2")
        XCTAssertTrue(session.isHistorical)
        XCTAssertEqual(SessionArchivePresentation.strategy(name: session.strategyName, version: session.strategyVersion), "Star V3.2")
    }

    func testMissingStrategyIdentityDoesNotInventStarV3() {
        XCTAssertEqual(SessionArchivePresentation.strategy(name: nil, version: nil), "Stratégie non fournie")
        XCTAssertEqual(SessionArchivePresentation.strategy(name: "Other", version: "0.9"), "Other · 0.9")
    }

    func testArchivedSessionEngineCannotBeActive() throws {
        let session = try detail(status: "stopped", lifecycle: "waiting_buy")
        XCTAssertEqual(PremiumEngineState.make(session: session, cached: false), .stopped)
    }

    func testEngineObservationRequiresFreshRunningSession() throws {
        let fresh = try detail(status: "running", lifecycle: "waiting_buy")
        XCTAssertEqual(PremiumEngineState.make(session: fresh, cached: false), .observing)
        XCTAssertEqual(PremiumEngineState.make(session: fresh, cached: true), .unknown)
        let stale = try detail(status: "running", lifecycle: "waiting_buy", freshness: "stale")
        XCTAssertEqual(PremiumEngineState.make(session: stale, cached: false), .unknown)
    }

    func testExplicitBlockIsDistinctFromPendingReconciliation() throws {
        let blocked = try detail(status: "safety_blocked", lifecycle: "waiting_buy")
        XCTAssertEqual(PremiumEngineState.make(session: blocked, cached: false), .blocked)
        let pending = try detail(status: "running", lifecycle: "reconciliation_pending")
        XCTAssertNotEqual(PremiumEngineState.make(session: pending, cached: false), .blocked)
    }

    func testUnknownStatusDoesNotBecomeActiveFromHTTPData() throws {
        let session = try detail(status: "future_status", lifecycle: "position_open")
        XCTAssertEqual(PremiumEngineState.make(session: session, cached: false), .unknown)
    }

    func testMissingZeroAndNaNPnLAreNeutral() {
        XCTAssertEqual(PremiumValueTone.pnl(nil), .neutral)
        XCTAssertEqual(PremiumValueTone.pnl(MoneyAmount(nil, currency: "EUR")), .neutral)
        XCTAssertEqual(PremiumValueTone.pnl(MoneyAmount(0, currency: "EUR")), .neutral)
        XCTAssertEqual(PremiumValueTone.pnl(MoneyAmount(.nan, currency: "EUR")), .neutral)
    }

    func testPnLSignUsesDecimalWithoutRoundingTinyLossToZero() {
        XCTAssertEqual(PremiumValueTone.pnl(MoneyAmount(Decimal(string: "-0.00000000000000000001"), currency: "USDC")), .negative)
        XCTAssertEqual(PremiumValueTone.pnl(MoneyAmount(Decimal(string: "0.00000000000000000001"), currency: "USDC")), .positive)
    }

    func testPendingIncludesPartialAndReconciliationButExcludesFinalStatuses() {
        for status in OrderStatus.allCases {
            let expected: Bool = [.submissionStarted, .submitted, .open, .partiallyFilled, .reconciliationRequired, .reconciliationBlocked, .reconciliationFailed].contains(status)
            XCTAssertEqual(PremiumOrderFilter.pending.includes(order(status: status)), expected, "\(status)")
        }
    }

    func testDirectionalFiltersDoNotMislabelUnknownSide() {
        XCTAssertTrue(PremiumOrderFilter.buys.includes(order(status: .filled, side: .buy)))
        XCTAssertFalse(PremiumOrderFilter.sells.includes(order(status: .filled, side: .buy)))
        XCTAssertFalse(PremiumOrderFilter.buys.includes(order(status: .unknown, side: .unknown)))
        XCTAssertTrue(PremiumOrderFilter.all.includes(order(status: .unknown, side: .unknown)))
    }

    func testMidnightBodyTextMeetsNormalTextContrastOnAllSurfaces() {
        for surface in [MidnightPalette.background, .surface, .surfaceElevated] {
            for text in [MidnightPalette.textPrimary, .textSecondary, .accentMint, .success, .loss, .warning, .info] {
                let ratio = (max(luminance(text), luminance(surface)) + 0.05) / (min(luminance(text), luminance(surface)) + 0.05)
                XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(text) on \(surface)")
            }
        }
    }

    private func luminance(_ color: MidnightPalette) -> Double {
        let hex = color.rawValue
        let components = [Double((hex >> 16) & 255), Double((hex >> 8) & 255), Double(hex & 255)].map { component in
            let value = component / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
    }

    private func detail(status: String, lifecycle: String, freshness: String = "fresh") throws -> SessionDetail {
        let payload: [String: Any] = ["id": "42", "status": status, "lifecycle_state": lifecycle, "freshness": ["status": freshness], "display_symbol": "SOL/USDC"]
        return try JSONDecoder().decode(RealSessionDetailDTO.self, from: JSONSerialization.data(withJSONObject: payload)).mapped()
    }

    private func order(status: OrderStatus, side: HistoryOrderSide = .buy) -> SessionOrder {
        SessionOrder(id: "fixture", side: side, orderType: nil, status: status, statusLabel: nil, provider: .kraken, exchangeOrderID: nil, symbol: "SOL/USDC", requestedQuantity: nil, executedQuantity: nil, limitPrice: nil, averageFillPrice: nil, requestedQuoteAmount: nil, executedQuoteAmount: nil, feesQuote: nil, feeRateEffective: nil, liquidityRole: nil, reconciliationState: nil, createdAt: nil, updatedAt: nil, filledAt: nil, realizedPnLQuote: nil, realizedPnLNetQuote: nil)
    }
}
