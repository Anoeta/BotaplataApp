import XCTest
@testable import BotaplataApp

final class TradingChartPresentationTests: XCTestCase { func testPresentationFlagsAndRange() { let chart = PreviewFixtures.tradingChart(range: .sevenDays); let model = RealTradingChartRenderModel.make(chart: chart); XCTAssertTrue(model.hasVWAP); XCTAssertTrue(model.hasEMA200); XCTAssertTrue(model.hasBollinger); XCTAssertTrue(model.hasVolume); XCTAssertEqual(TradingChartRange.oneHour.displayTitle, "1 h"); XCTAssertEqual(TradingChartRange.sevenDays.cacheTTL, 300); XCTAssertEqual(TradingMarkerKind.partialBuy.title, "Achat partiellement exécuté") } }
