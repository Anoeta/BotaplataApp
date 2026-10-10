import XCTest
@testable import BotaplataApp

final class PremiumRedesignTests: XCTestCase {
    private func candle(_ id: String, start: TimeInterval, price: Decimal) -> TradingCandle {
        TradingCandle(id: id, openTime: Date(timeIntervalSince1970: start), closeTime: Date(timeIntervalSince1970: start + 60), isClosed: true, open: price, high: price, low: price, close: price, volume: nil, vwap: nil, ema200: nil, bollingerUpper: nil, bollingerMiddle: nil, bollingerLower: nil)
    }
    private func chart(_ candles: [TradingCandle]) -> TradingChart {
        TradingChart(sessionID: "27", symbol: "SOLUSDC", displaySymbol: "SOL/USDC", quoteAsset: "USDC", range: .sixHours, timeframe: "1m", generatedAt: Date(timeIntervalSince1970: 600), dataSource: "persisted_ohlcv", isComplete: true, hasMore: false, nextBefore: nil, candles: candles, markers: [], levels: TradingLevels(entryPrice: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, trailingStopPrice: nil), warnings: [])
    }
    private func session(status: String = "running", health: RuntimeHealthState = .healthy, freshness: FreshnessStatus = .fresh) -> SessionDetail {
        let fee = FeeAwareSummary(executionPrice: nil, costBasisPrice: nil, buyFeeQuote: nil, buyFeeRateEffective: nil, estimatedSellFeeQuote: nil, estimatedSellFeeRate: nil, estimatedSellFeeSource: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, minimumNetProfitRate: nil, estimatedSlippageRate: nil, unrealizedPnLGrossQuote: nil, unrealizedPnLNetEstimatedQuote: nil, realizedPnLNetQuote: nil, totalEstimatedCycleFeesQuote: nil, liquidityRole: nil)
        return SessionDetail(id: "27", pair: "SOL/USDC", provider: .kraken, backendStatus: status, lifecycle: .waitingBuy, runtimeHealth: health, freshness: DataFreshness(status: freshness, updatedAt: nil, source: .backend), currentPrice: nil, position: nil, decision: StrategyDecisionSummary(title: "Attente", detail: "", favorableConditions: nil, requiredConditions: nil), activeOrder: nil, pnl: nil, feeAware: fee, warnings: [])
    }
    private func fixture(_ name: String) throws -> Data {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/MobileV1")
        return try Data(contentsOf: directory.appendingPathComponent(name + ".json"))
    }

    func testEmptyHistoryHasNoPriceReturnOrSelection() {
        let model = PremiumMarketPresentation(chart: chart([]))
        XCTAssertTrue(model.points.isEmpty)
        XCTAssertNil(model.change)
        XCTAssertNil(model.nearest(to: Date()))
        XCTAssertLessThan(model.domain.lowerBound, model.domain.upperBound)
    }
    func testOneObservationDoesNotInventReturn() {
        let model = PremiumMarketPresentation(chart: chart([candle("a", start: 0, price: 100)]))
        XCTAssertNil(model.change)
        XCTAssertEqual(model.points.count, 1)
        XCTAssertLessThan(model.domain.lowerBound, 100)
        XCTAssertGreaterThan(model.domain.upperBound, 100)
    }
    func testReturnIsForDisplayedObservationsAndKeepsDecimalPrecision() {
        let model = PremiumMarketPresentation(chart: chart([candle("b", start: 60, price: 110), candle("a", start: 0, price: 100)]))
        XCTAssertEqual(model.change, Decimal(string: "0.1"))
        XCTAssertEqual(model.firstObservation, Date(timeIntervalSince1970: 60))
        XCTAssertEqual(model.lastObservation, Date(timeIntervalSince1970: 120))
    }
    func testMissingCandlesInterruptSeriesAndInvalidateReturn() {
        let model = PremiumMarketPresentation(chart: chart([candle("a", start: 0, price: 100), candle("b", start: 180, price: 110)]))
        XCTAssertEqual(model.gaps.count, 1)
        XCTAssertEqual(model.points.map(\.segment), [0, 1])
        XCTAssertNil(model.change)
        XCTAssertNil(model.nearest(to: Date(timeIntervalSince1970: 100)))
    }
    func testSelectionFindsObservedPoint() {
        let model = PremiumMarketPresentation(chart: chart([candle("a", start: 0, price: 100), candle("b", start: 60, price: 110)]))
        XCTAssertEqual(model.nearest(to: Date(timeIntervalSince1970: 115))?.id, "b")
    }
    func testZeroPriceDoesNotCreateZeroReturn() {
        let model = PremiumMarketPresentation(chart: chart([candle("a", start: 0, price: 0), candle("b", start: 60, price: 110)]))
        XCTAssertEqual(model.points.count, 1)
        XCTAssertNil(model.change)
    }
    func testHealthyRequiresRunningFreshBackendMonitoring() {
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(), cached: false), .healthy)
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(health: .unknown), cached: false), .unknown)
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(status: "paused"), cached: false), .unknown)
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(), cached: true), .unknown)
    }
    func testSafetyAndFreshnessAreIndependentOfConnectivity() {
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(status: "safety_blocked"), cached: false), .blocked)
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(status: "reconciliation_blocked"), cached: true), .blocked)
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(freshness: .stale), cached: false), .degraded)
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: session(health: .degraded), cached: false), .degraded)
    }
    func testPendingReconciliationDoesNotInventSafetyBlock() {
        var pending = session()
        pending.reconciliation = Warning(id: "reconciliation_pending", severity: .information, title: "Vérification", message: "État d’ordre à vérifier")
        XCTAssertEqual(PremiumSupervisionPresentation.state(session: pending, cached: false), .healthy)
    }
    func testRSI43IsAvailableEvenWhenUnfavorable() {
        let indicator = StrategyIndicator(id: "rsi", name: "RSI", valueRaw: "43", status: "unfavorable", help: "", technicalDetail: nil)
        XCTAssertEqual(PremiumIndicatorPresentation.status(indicator), "Défavorable à l’entrée")
        XCTAssertEqual(StrategyIndicatorSet(indicators: [indicator]).rsi, 43)
    }
    func testMissingRSIIsNotNeutralOrZero() {
        let indicator = StrategyIndicator(id: "rsi", name: "RSI", valueRaw: nil, status: "neutral", help: "", technicalDetail: nil)
        XCTAssertEqual(PremiumIndicatorPresentation.status(indicator), "Indisponible")
        XCTAssertNil(StrategyIndicatorSet(indicators: [indicator]).rsi)
        XCTAssertEqual(FinancialFormatters.money(nil), "—")
    }
    func testBollingerBackendBandContractIsPreserved() throws {
        let data = Data(#"{"upper":"151.1","middle":"149.5","lower":"147.9","status":"neutral"}"#.utf8)
        let dto = try JSONCoding.decoder.decode(StrategyExplanationIndicatorDTO.self, from: data)
        XCTAssertEqual(dto.value, "Basse 147.9 · Médiane 149.5 · Haute 151.1")
    }
    func testChartFixturesDecodeWithoutInventingCandles() throws {
        for name in ["empty", "partial_history", "buy_sell_markers", "1h", "6h", "24h", "7d"] {
            let envelope = try JSONCoding.decoder.decode(APIEnvelope<RealSessionChartDTO>.self, from: fixture("real_session_chart_" + name))
            let mapped = try RealSessionChartMapper.map(envelope: envelope)
            XCTAssertEqual(mapped.candles.count, envelope.data?.series.count)
            XCTAssertEqual(mapped.dataSource, "persisted_ohlcv")
            if name == "empty" { XCTAssertTrue(PremiumMarketPresentation(chart: mapped).points.isEmpty) }
            if name == "buy_sell_markers" { XCTAssertTrue(mapped.markers.contains { $0.kind == .buy }); XCTAssertTrue(mapped.markers.contains { $0.kind == .partialSell }) }
        }
    }
    func testEntryScoreRemainsSeparateFromRebound() throws {
        let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixture("StrategyExplanation/wait_3_of_4"))
        XCTAssertEqual(dto.data.score?.current?.value, 3)
        XCTAssertEqual(dto.data.score?.required?.value, 4)
        XCTAssertEqual(dto.data.indicators.rsi?.value, "31.8")
    }
    func testActualBackendRSIAndAnalysisAliases() throws {
        let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixture("StrategyExplanation/backend_rsi_43"))
        let model = dto.mapped()
        XCTAssertEqual(model.analysis.timeframe, "5m")
        XCTAssertEqual(model.decision.technicalDetail, "entry_threshold_not_reached")
        XCTAssertFalse(model.analysis.freshness.isStale)
        XCTAssertEqual(model.indicators.rsi, 43)
        XCTAssertEqual(model.conditions.first { $0.code == "rsi" }?.status, .unfavorable)
        XCTAssertEqual(StrategyRSIPresentation(explanation: model).isRSIUnavailable, false)
        XCTAssertTrue(model.indicators.value(for: "bollinger")?.valueRaw?.contains("159.00") == true)
    }
    func testActualBackendStaleWarningDoesNotBreakWholeAnalysis() throws {
        let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixture("StrategyExplanation/backend_stale"))
        let model = dto.mapped()
        XCTAssertTrue(model.analysis.freshness.isStale)
        XCTAssertEqual(model.decision.code, .dataStale)
        XCTAssertEqual(model.warnings.first?.id, "stale_strategy_decision")
        XCTAssertEqual(model.warnings.first?.severity, .warning)
    }
    func testActualBackendProtectionAliasesKeepAmounts() throws {
        let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixture("StrategyExplanation/backend_position"))
        let model = dto.mapped()
        XCTAssertEqual(model.decision.code, .positionOpen)
        XCTAssertEqual(model.positionProtection?.unrealizedPnLRaw, "10.0")
        XCTAssertEqual(model.positionProtection?.minimumProfitablePriceRaw, "151")
        XCTAssertEqual(model.positionProtection?.breakEvenPriceRaw, "150.5")
        XCTAssertNil(model.positionProtection?.trailingStopRaw)
    }
    func testLocalOpenOrderLabelDoesNotClaimExchangeConfirmation() {
        XCTAssertEqual(OrderStatus.open.label, "Ouvert · état local")
    }
}
