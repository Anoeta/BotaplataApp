import XCTest

@testable import BotaplataApp

final class StrategyExplanationTests: XCTestCase {
  let fixtures = [
    "wait_2_of_4", "wait_3_of_4", "blocked_4_of_4_ohlcv_stale", "buy_order_submitted_4_of_4",
    "position_open", "history_preparing", "data_stale", "session_blocked", "kraken_unavailable",
    "no_indicators_available",
  ]
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
      XCTAssertTrue(
        model.conditions.allSatisfy { $0.technicalDetail == nil || !$0.technicalDetail!.isEmpty })
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
    let data =
      #"{"data":{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}},"meta":{"data_source":"outer"}}"#
      .data(using: .utf8)!

    XCTAssertThrowsError(try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: data))
  }

  func testStrategyIdentityDecodesWithoutLegacyID() throws {
    let json =
      #"{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3","version":"3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}}"#
      .data(using: .utf8)!
    let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: json)
    let model = dto.mapped()

    XCTAssertEqual(dto.data.strategy.code, "star_v3")
    XCTAssertEqual(dto.data.strategy.name, "Star Strategy V3")
    XCTAssertEqual(model.strategy.code, "star_v3")
    XCTAssertEqual(model.strategy.name, "Star Strategy V3")
  }

  func testRealWaitingBuyConditionsWithoutIDsUseCodeIdentityAndPreserveNullValues() throws {
    let json = #"""
        {"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3","version":"3"},"decision":{"code":"waiting_buy","label":"Attente achat","summary":"Score 3/4"},"score":{"current":3,"required":4,"maximum":4,"favorable_conditions":3,"total_conditions":9},"analysis":{"timeframe":"1m","candle_close_time":"2026-07-19T12:30:00Z","freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[{"code":"rsi","label":"RSI","status":"favorable","value":"42.631071","threshold":"40","summary":"RSI favorable","technical_detail":"persisted","importance":"primary"},{"code":"ema200_slope","label":"Pente EMA200","status":"unavailable","value":null,"summary":"Pente indisponible"},{"code":"adx","label":"ADX","status":"favorable","value":"23"},{"code":"vwap","label":"VWAP","status":"favorable","value":"79.2"},{"code":"bollinger","label":"Bollinger","status":"neutral","value":"mid"},{"code":"volume","label":"Volume","status":"neutral","value":null},{"code":"spread","label":"Spread","status":"favorable","value":"0.01"},{"code":"atr","label":"ATR","status":"neutral","value":"1.2"},{"code":"cooldown","label":"Cooldown","status":"favorable","value":"ok"}],"blockers":[{"code":"ohlcv_stale","label":"Données OHLCV","severity":"blocking","summary":"Vérifier la fraîcheur","technical_detail":"no raw values","is_recoverable":true},{"code":"risk_guard","label":"Garde-fou risque","severity":"warning","summary":"Risque à valider","is_recoverable":false}],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}}
      """#.data(using: .utf8)!

    let model = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: json).mapped()
    XCTAssertEqual(model.decision.rawValue, "waiting_buy")
    XCTAssertEqual(model.score?.current, 3)
    XCTAssertEqual(model.score?.required, 4)
    XCTAssertEqual(model.conditions.count, 9)
    XCTAssertEqual(model.conditions.first?.id, model.conditions.first?.code)
    XCTAssertEqual(model.conditions.first?.code, "rsi")
    XCTAssertEqual(model.conditions.first?.valueRaw, "42.631071")
    let conditionWithoutValue = try XCTUnwrap(model.conditions.first { $0.code == "ema200_slope" })
    XCTAssertEqual(conditionWithoutValue.id, "ema200_slope")
    XCTAssertNil(conditionWithoutValue.valueRaw)
    XCTAssertEqual(model.blockers.count, 2)
    XCTAssertEqual(model.blockers.first?.id, model.blockers.first?.code)
    XCTAssertEqual(model.blockers.first?.code, "ohlcv_stale")
    XCTAssertEqual(model.blockers.first?.recoverable, true)
  }

  func testUnknownEnumsFallbackWithoutFailingDecode() throws {
    let json =
      #"{"data":{"session_id":"x","strategy":{"code":"s","name":"Strategy S"},"decision":{"code":"new_decision","label":"Nouveau","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"new_regime","label":"R"},"momentum":{"code":"new_momentum","label":"M"}},"conditions":[{"code":"c","label":"C","status":"new_status","summary":"S"}],"blockers":[{"code":"b","label":"B","summary":"S","severity":"new_severity"}],"indicators":{},"warnings":[]},"meta":{}}"#
      .data(using: .utf8)!
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
    let json = baseExplanation(
      score:
        #"{"current":"3","required":"4","maximum":"4","favorable_conditions":"3","total_conditions":"4"}"#
    )
    let model = try JSONCoding.decoder.decode(
      RealStrategyExplanationDTO.self, from: Data(json.utf8)
    ).mapped()

    XCTAssertEqual(model.score?.current, 3)
    XCTAssertEqual(model.score?.required, 4)
    XCTAssertEqual(model.score?.maximum, 4)
    XCTAssertEqual(model.score?.favorableConditions, 3)
    XCTAssertEqual(model.score?.totalConditions, 4)
  }

  func testScoreAbsentDoesNotBuildDomainScore() throws {
    let json = baseExplanation(score: nil)
    let model = try JSONCoding.decoder.decode(
      RealStrategyExplanationDTO.self, from: Data(json.utf8)
    ).mapped()

    XCTAssertNil(model.score)
  }

  func testNullableScoreFieldsRemainNil() throws {
    let json = baseExplanation(
      score:
        #"{"current":null,"required":4,"maximum":4,"favorable_conditions":null,"total_conditions":4}"#
    )
    let model = try JSONCoding.decoder.decode(
      RealStrategyExplanationDTO.self, from: Data(json.utf8)
    ).mapped()

    XCTAssertNil(model.score?.current)
    XCTAssertEqual(model.score?.required, 4)
    XCTAssertEqual(model.score?.maximum, 4)
    XCTAssertNil(model.score?.favorableConditions)
    XCTAssertEqual(model.score?.totalConditions, 4)
  }

  func testRejectsDecimalScoreField() throws {
    let json = baseExplanation(
      score:
        #"{"current":3.5,"required":4,"maximum":4,"favorable_conditions":3,"total_conditions":4}"#)

    XCTAssertThrowsError(
      try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)))
  }

  func testRejectsNonNumericScoreString() throws {
    let json = baseExplanation(
      score:
        #"{"current":"abc","required":4,"maximum":4,"favorable_conditions":3,"total_conditions":4}"#
    )

    XCTAssertThrowsError(
      try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)))
  }

  private func fixture(_ name: String) throws -> RealStrategyExplanationDTO {
    try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: fixtureData(name))
  }

  private func fixtureData(_ name: String) throws -> Data {
    let url = Bundle(for: Self.self).url(
      forResource: name, withExtension: "json",
      subdirectory: "Fixtures/MobileV1/StrategyExplanation")!
    return try Data(contentsOf: url)
  }

  private func baseExplanation(score: String?) -> String {
    let scoreField = score.map { #", "score": \#($0)"# } ?? ""
    return
      #"{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3","version":"3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"}\#(scoreField),"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[],"blockers":[],"indicators":{},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}}"#
  }
}

extension StrategyExplanationTests {
  func testStrategyExplanationPreservesRSIFromCanonicalIndicatorsWhenConditionValueIsNull() throws {
    let json = #"{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3","version":"3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"score":{"current":3,"required":4},"analysis":{"candle_close_time":"2026-07-19T12:30:00Z","freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[{"code":"rsi","label":"RSI","status":"pending","value":null}],"blockers":[],"indicators":{"rsi":42.631071},"warnings":[]},"meta":{"data_source":"persisted_strategy_decision"}}"#
    let dto = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8))
    let model = dto.mapped()
    let rsiCondition = try XCTUnwrap(model.conditions.first { $0.code == "rsi" })
    let viewModel = StrategyRSIPresentation(explanation: model)

    XCTAssertEqual(model.indicators.rsi, Decimal(string: "42.631071"))
    XCTAssertNil(rsiCondition.valueRaw)
    XCTAssertEqual(viewModel.rsiDisplayValue, "42,6")
    XCTAssertFalse(viewModel.isRSIUnavailable)
    XCTAssertEqual(viewModel.rsiStatusText, "À confirmer")
  }

  func testStrategyExplanationRSIUnavailableOnlyWhenNoSourceProvidesIt() throws {
    let json = #"{"data":{"session_id":"27","strategy":{"code":"star_v3","name":"Star Strategy V3"},"decision":{"code":"wait","label":"Attente","summary":"Résumé"},"analysis":{"freshness":{"status":"fresh","is_stale":false}},"market":{"regime":{"code":"range","label":"Range"},"momentum":{"code":"neutral","label":"Neutre"}},"conditions":[{"code":"rsi","label":"RSI","status":"pending","value":null}],"blockers":[],"indicators":{},"warnings":[]},"meta":{}}"#
    let model = try JSONCoding.decoder.decode(RealStrategyExplanationDTO.self, from: Data(json.utf8)).mapped()
    let viewModel = StrategyRSIPresentation(explanation: model)
    XCTAssertNil(model.indicators.rsi)
    XCTAssertTrue(viewModel.isRSIUnavailable)
  }
}
