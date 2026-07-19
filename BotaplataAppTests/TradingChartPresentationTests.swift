import XCTest
@testable import BotaplataApp

final class TradingChartPresentationTests: XCTestCase {
    func testPresentationFlagsAndRange() { let chart = PreviewFixtures.tradingChart(range: .sevenDays); let model = RealTradingChartRenderModel.make(chart: chart); XCTAssertTrue(model.hasVWAP); XCTAssertTrue(model.hasEMA200); XCTAssertTrue(model.hasBollinger); XCTAssertTrue(model.hasVolume); XCTAssertEqual(TradingChartRange.oneHour.displayTitle, "1 h"); XCTAssertEqual(TradingChartRange.sevenDays.cacheTTL, 300); XCTAssertEqual(TradingMarkerKind.partialBuy.title, "Achat partiellement exécuté") }
    func testNearestCandleCases() { let candles = makeCandles(count: 3); XCTAssertNil(TradingChartPresentation.nearestCandle(to: Date(), in: [])); XCTAssertEqual(TradingChartPresentation.nearestCandle(to: candles[1].openTime, in: candles)?.id, "c1"); XCTAssertEqual(TradingChartPresentation.nearestCandle(to: Date(timeIntervalSince1970: 90), in: candles)?.id, "c1"); XCTAssertEqual(TradingChartPresentation.nearestCandle(to: Date(timeIntervalSince1970: -100), in: candles)?.id, "c0"); XCTAssertEqual(TradingChartPresentation.nearestCandle(to: Date(timeIntervalSince1970: 1000), in: candles)?.id, "c2"); XCTAssertEqual(TradingChartPresentation.nearestCandle(to: Date(timeIntervalSince1970: 30), in: candles)?.id, "c0") }
    func testCandleWidthBounds() { XCTAssertEqual(TradingChartPresentation.candleWidth(availableWidth: 0, candleCount: 0), 3); XCTAssertEqual(TradingChartPresentation.candleWidth(availableWidth: 320, candleCount: 1), 10); XCTAssertGreaterThanOrEqual(TradingChartPresentation.candleWidth(availableWidth: 320, candleCount: 672), 2); XCTAssertLessThanOrEqual(TradingChartPresentation.candleWidth(availableWidth: 320, candleCount: 60), 10) }
    func testContinuousSegments() { var candles = makeCandles(count: 6); XCTAssertEqual(TradingChartPresentation.continuousSegments(from: candles, value: \.vwap).count, 0); candles[0] = candle(id: "a", t: 0, vwap: 1); candles[1] = candle(id: "b", t: 60, vwap: 2); candles[3] = candle(id: "d", t: 180, vwap: 4); candles[4] = candle(id: "e", t: 240, vwap: 5); let segments = TradingChartPresentation.continuousSegments(from: candles, value: \.vwap); XCTAssertEqual(segments.map(\.count), [2, 2]); XCTAssertEqual(segments[1].first?.id, "1-d") }
    func testPriceDomainIncludesBackendValuesWithoutZeroForcing() { let candles = [candle(id: "c", t: 0, low: 74, high: 74, vwap: 74, ema200: 74, bollingerUpper: 74, bollingerMiddle: 74, bollingerLower: 74)]; let marker = ChartRenderableMarker(id: "m", kind: .buy, timestamp: Date(), price: 80, quantity: nil, orderID: nil, title: "buy"); let level = ChartRenderableLevel(id: "l", title: "entry", price: 70, offset: 0); let domain = TradingChartPresentation.priceDomain(candles: candles, markers: [marker], levels: [level]); XCTAssertNotNil(domain); XCTAssertLessThan(domain!.lowerBound, 70); XCTAssertGreaterThan(domain!.upperBound, 80); XCTAssertGreaterThan(domain!.lowerBound, 0) }
    func testWarningsRemainNonBlockingAndDeduplicatedInModel() { let warning = Warning(id: "invalid_candle_filtered", severity: .warning, title: "Bougie ignorée", message: "invalid_candle_filtered"); let chart = FakeChartRepository.chart(candles: makeTradingCandles(count: 1), warnings: [warning, warning]); let model = RealTradingChartRenderModel.make(chart: chart); XCTAssertEqual(model.candles.count, 1); XCTAssertEqual(chart.warnings.first?.message, "invalid_candle_filtered") }
    private func makeCandles(count: Int) -> [ChartRenderableCandle] { (0..<count).map { candle(id: "c\($0)", t: TimeInterval($0 * 60)) } }
    private func candle(id: String, t: TimeInterval, low: Double = 1, high: Double = 2, vwap: Double? = nil, ema200: Double? = nil, bollingerUpper: Double? = nil, bollingerMiddle: Double? = nil, bollingerLower: Double? = nil) -> ChartRenderableCandle { ChartRenderableCandle(id: id, openTime: Date(timeIntervalSince1970: t), closeTime: Date(timeIntervalSince1970: t + 60), isClosed: true, open: low, high: high, low: low, close: high, volume: nil, vwap: vwap, ema200: ema200, bollingerUpper: bollingerUpper, bollingerMiddle: bollingerMiddle, bollingerLower: bollingerLower) }
    private func makeTradingCandles(count: Int) -> [TradingCandle] { (0..<count).map { TradingCandle(id: "c\($0)", openTime: Date(timeIntervalSince1970: Double($0 * 60)), closeTime: Date(timeIntervalSince1970: Double($0 * 60 + 60)), isClosed: true, open: 1, high: 2, low: 1, close: 2, volume: nil, vwap: nil, ema200: nil, bollingerUpper: nil, bollingerMiddle: nil, bollingerLower: nil) } }
    func testRangeRawValuesMatchBackendContract() {
        XCTAssertEqual(TradingChartRange.oneHour.rawValue, "1h")
        XCTAssertEqual(TradingChartRange.sixHours.rawValue, "6h")
        XCTAssertEqual(TradingChartRange.oneDay.rawValue, "24h")
        XCTAssertEqual(TradingChartRange.sevenDays.rawValue, "7d")
        let rawValues = TradingChartRange.allCases.map(\.rawValue).joined(separator: ",")
        XCTAssertFalse(rawValues.contains("oneHour"))
        XCTAssertFalse(rawValues.contains("sixHours"))
        XCTAssertFalse(rawValues.contains("24hours"))
        XCTAssertFalse(rawValues.contains("sevenDays"))
    }

    func testZeroLevelsAreHidden() {
        let levels = TradingChartPresentation.renderableLevels(TradingLevels(entryPrice: 0, breakEvenPrice: 74.4, minimumProfitableExitPrice: nil, trailingStopPrice: 0))
        XCTAssertEqual(levels.map(\.id), ["breakEven"])
    }

}
