import XCTest
@testable import BotaplataApp

final class MobileV1ChartContractDecodingTests: XCTestCase {
    func testAllBackendChartFixturesDecode() throws {
        for name in ["real_session_chart_1h", "real_session_chart_6h", "real_session_chart_24h", "real_session_chart_7d", "real_session_chart_empty", "real_session_chart_position_open", "real_session_chart_buy_sell_markers", "real_session_chart_partial_history"] {
            let envelope = try decode(name)
            let dto = try XCTUnwrap(envelope.data)
            XCTAssertEqual(dto.sessionID, "s1")
            XCTAssertFalse(dto.timeframe.isEmpty)
            XCTAssertEqual(dto.symbol, "SOLUSDC")
            XCTAssertNotNil(dto.generatedAt)
            if !dto.series.isEmpty { XCTAssertEqual(dto.series[0].open.value, Decimal(string: "74.5")) }
            let chart = try RealSessionChartMapper.map(envelope: envelope)
            XCTAssertEqual(chart.quoteAsset, "USDC")
            XCTAssertFalse(chart.dataSource.isEmpty)
            XCTAssertEqual(chart.hasMore, false)
            XCTAssertEqual(chart.isComplete, true)
            XCTAssertFalse(chart.warnings.isEmpty)
        }
    }
    private func decode(_ name: String) throws -> APIEnvelope<RealSessionChartDTO> { let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/MobileV1") ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/MobileV1/\(name).json"); return try JSONCoding.decoder.decode(APIEnvelope<RealSessionChartDTO>.self, from: Data(contentsOf: url)) }
}
