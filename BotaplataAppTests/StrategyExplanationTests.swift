import XCTest
@testable import BotaplataApp

final class StrategyExplanationTests: XCTestCase {
    let fixtures = ["wait_2_of_4", "wait_3_of_4", "blocked_4_of_4_ohlcv_stale", "buy_order_submitted_4_of_4", "position_open", "history_preparing", "data_stale", "session_blocked", "kraken_unavailable", "no_indicators_available"]
    func testDecodesAndMapsAllStrategyExplanationFixtures() throws {
        for name in fixtures {
            let dto = try fixture(name)
            let model = dto.mapped()
            XCTAssertEqual(model.strategy.code, "star_v3")
            XCTAssertFalse(model.decision.label.isEmpty)
            XCTAssertEqual(model.meta.source, "persisted_strategy_decision")
            XCTAssertEqual(model.conditions.count, 4)
            XCTAssertTrue(model.conditions.allSatisfy { $0.technicalDetail == nil || !$0.technicalDetail!.isEmpty })
            XCTAssertTrue(model.indicators.indicators.allSatisfy { !$0.help.isEmpty })
        }
    }

    func testDecodesRealSingleEnvelopeFixture() throws {
        let data = try fixtureData("wait_3_of_4")
        let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: data)

        XCTAssertEqual(dto.data.sessionID, "27")
        XCTAssertEqual(dto.meta.dataSource, "persisted_strategy_decision")
    }

    func testRejectsLegacyDoubleEnvelopeContract() throws {
        let data = #"{"data":{"data":{"session_id":"27","strategy":{"id":"star_v3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}},"meta":{"data_source":"outer"}}"#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: data))
    }
    func testUnknownEnumsFallbackWithoutFailingDecode() throws {
        let json = #"{"data":{"session_id":"x","strategy":{"id":"s"},"decision":{"code":"new_decision","label":"Nouveau","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"new_regime","label":"R"},"momentum":{"code":"new_momentum","label":"M"}},"conditions":[{"id":"c","label":"C","status":"new_status","summary":"S"}],"blockers":[{"id":"b","label":"B","summary":"S","severity":"new_severity"}],"indicators":{},"warnings":[]},"meta":{}}"#.data(using: .utf8)!
        let model = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: json).mapped()
        XCTAssertEqual(model.decision.code, .unknown)
        XCTAssertEqual(model.market.regime.code, .unknown)
        XCTAssertEqual(model.market.momentum.code, .unknown)
        XCTAssertEqual(model.conditions[0].status, .unknown)
        XCTAssertEqual(model.blockers[0].severity, .unknown)
    }
    func testPresentationVisibilityRules() {
        let explanation = PreviewFixtures.strategyExplanationWait3
        XCTAssertTrue(explanation.blockers.isEmpty)
        XCTAssertNil(explanation.positionProtection)
        XCTAssertEqual(explanation.score?.currentRaw, "3")
    }
    private func fixture(_ name: String) throws -> RealStrategyExplanationDTO {
        try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixtureData(name))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures/MobileV1/StrategyExplanation")!
        return try Data(contentsOf: url)
    }
}
