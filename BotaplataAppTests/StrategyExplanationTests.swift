import XCTest
@testable import BotaplataApp

final class StrategyExplanationTests: XCTestCase {
    let fixtures = ["wait_2_of_4", "wait_3_of_4", "blocked_4_of_4_ohlcv_stale", "buy_order_submitted_4_of_4", "position_open", "history_preparing", "data_stale", "session_blocked", "kraken_unavailable", "no_indicators_available"]
    func testDecodesAndMapsAllStrategyExplanationFixtures() throws {
        for name in fixtures {
            let dto = try fixture(name)
            let model = dto.mapped()
            XCTAssertEqual(dto.data.strategy.code, "star_v3")
            XCTAssertEqual(dto.data.strategy.name, "Star Strategy V3")
            XCTAssertEqual(model.strategy.code, "star_v3")
            XCTAssertEqual(model.strategy.name, "Star Strategy V3")
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
        XCTAssertEqual(dto.data.strategy.code, "star_v3")
        XCTAssertEqual(dto.data.strategy.name, "Star Strategy V3")
        XCTAssertEqual(dto.meta.dataSource, "persisted_strategy_decision")
    }

    func testRejectsLegacyDoubleEnvelopeContract() throws {
        let data = #"{"data":{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}},"meta":{"data_source":"outer"}}"#.data(using: .utf8)!

        XCTAssertThrowsError(try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: data))
    }

    func testStrategyIdentityDecodesWithoutLegacyID() throws {
        let json = #"{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3","version":"3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}}"#.data(using: .utf8)!
        let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: json)
        let model = dto.mapped()

        XCTAssertEqual(dto.data.strategy.code, "star_v3")
        XCTAssertEqual(dto.data.strategy.name, "Star Strategy V3")
        XCTAssertEqual(model.strategy.code, "star_v3")
        XCTAssertEqual(model.strategy.name, "Star Strategy V3")
    }
    func testUnknownEnumsFallbackWithoutFailingDecode() throws {
        let json = #"{"data":{"session_id":"x","strategy":{"code":"s","name":"Strategy S"},"decision":{"code":"new_decision","label":"Nouveau","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"new_regime","label":"R"},"momentum":{"code":"new_momentum","label":"M"}},"conditions":[{"id":"c","label":"C","status":"new_status","summary":"S"}],"blockers":[{"id":"b","label":"B","summary":"S","severity":"new_severity"}],"indicators":{},"warnings":[]},"meta":{}}"#.data(using: .utf8)!
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
        XCTAssertEqual(explanation.score?.current, 3)
    }


    func testScoreDecodesJSONNumbersAsDomainIntegers() throws {
        let model = try fixture("wait_3_of_4").mapped()

        XCTAssertEqual(model.score?.current, 3)
        XCTAssertEqual(model.score?.required, 4)
        XCTAssertEqual(model.score?.maximum, 4)
        XCTAssertEqual(model.score?.favorableConditions, 3)
        XCTAssertEqual(model.score?.totalConditions, 4)
    }

    func testScoreDecodesNumericStringsForLegacyCompatibility() throws {
        let json = baseExplanation(score: #"{"current":"3","required":"4","maximum":"4","favorable_conditions":"3","total_conditions":"4"}"#)
        let model = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)).mapped()

        XCTAssertEqual(model.score?.current, 3)
        XCTAssertEqual(model.score?.required, 4)
        XCTAssertEqual(model.score?.maximum, 4)
        XCTAssertEqual(model.score?.favorableConditions, 3)
        XCTAssertEqual(model.score?.totalConditions, 4)
    }

    func testScoreAbsentDoesNotBuildDomainScore() throws {
        let json = baseExplanation(score: nil)
        let model = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)).mapped()

        XCTAssertNil(model.score)
    }

    func testNullableScoreFieldsRemainNil() throws {
        let json = baseExplanation(score: #"{"current":null,"required":4,"maximum":4,"favorable_conditions":null,"total_conditions":4}"#)
        let model = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)).mapped()

        XCTAssertNil(model.score?.current)
        XCTAssertEqual(model.score?.required, 4)
        XCTAssertEqual(model.score?.maximum, 4)
        XCTAssertNil(model.score?.favorableConditions)
        XCTAssertEqual(model.score?.totalConditions, 4)
    }

    func testRejectsDecimalScoreField() throws {
        let json = baseExplanation(score: #"{"current":3.5,"required":4,"maximum":4,"favorable_conditions":3,"total_conditions":4}"#)

        XCTAssertThrowsError(try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)))
    }

    func testRejectsNonNumericScoreString() throws {
        let json = baseExplanation(score: #"{"current":"abc","required":4,"maximum":4,"favorable_conditions":3,"total_conditions":4}"#)

        XCTAssertThrowsError(try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)))
    }

    private func fixture(_ name: String) throws -> RealStrategyExplanationDTO {
        try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixtureData(name))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle(for: Self.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures/MobileV1/StrategyExplanation")!
        return try Data(contentsOf: url)
    }

    private func baseExplanation(score: String?) -> String {
        let scoreField = score.map { #", "score": \#($0)"# } ?? ""
        return #"{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3","version":"3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"}\#(scoreField),"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}}"#
    }
}
