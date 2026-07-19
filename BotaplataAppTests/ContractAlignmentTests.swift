import XCTest
@testable import BotaplataApp

final class ContractAlignmentTests: XCTestCase {
    func testPushPreferencesDecodeWithoutCategories() throws {
        let data = Data(#"{"updated_at":"2026-07-19T10:00:00Z"}"#.utf8)
        let prefs = try JSONCoding.decoder.decode(PushPreferences.self, from: data)
        XCTAssertEqual(prefs.categories, [])
    }

    func testPushPreferencesDecodeCategories() throws {
        let data = Data(#"{"categories":[{"event_type":"session_decision","enabled":true,"mandatory":false,"severity":"info"}],"updated_at":"2026-07-19T10:00:00Z"}"#.utf8)
        let prefs = try JSONCoding.decoder.decode(PushPreferences.self, from: data)
        XCTAssertEqual(prefs.categories.first?.eventType, "session_decision")
    }

    func testDecisionAdviceStringIsMappedWithoutDuplication() throws {
        let data = Data(#"{"decision":"wait","title":"Attente","detail":"Surveillance active","advice":"Conseil pédagogique","blockers":[],"buy_conditions":[],"sell_conditions":[]}"#.utf8)
        let dto = try JSONCoding.decoder.decode(RealDecisionDTO.self, from: data)
        let mapped = dto.mapped()
        XCTAssertEqual(mapped.detail, "Surveillance active")
        XCTAssertEqual(mapped.advice, "Conseil pédagogique")
        XCTAssertNotEqual(mapped.detail, mapped.advice)
    }

    func testAuthorizedDevicesObjectEnvelopeMapsCurrentDeviceID() throws {
        let data = Data(#"{"devices":[{"id":"dev-1","name":"iPhone","model":"iPhone","os_version":"26.5","app_version":"1.0","locale":"fr-FR","created_at":"2026-07-14T10:00:00Z","last_seen_at":null,"last_authenticated_at":"2026-07-14T10:00:00Z","is_current":false,"is_revoked":false}],"current_device_id":"dev-1"}"#.utf8)
        let dto = try JSONCoding.decoder.decode(AuthorizedDevicesResponseDTO.self, from: data)
        XCTAssertEqual(dto.currentDeviceID, "dev-1")
        XCTAssertTrue(dto.mappedDevices[0].isCurrent)
    }

    func testRealConditionBackendAliasesDecodeNullValueAndMapPreserved() throws {
        let data = Data(#"{"code":"rsi","label":"RSI","status":"unavailable","value":null}"#.utf8)
        let dto = try JSONCoding.decoder.decode(RealStrategyConditionDTO.self, from: data)
        let mapped = dto.mapped()
        XCTAssertEqual(mapped.key, "rsi")
        XCTAssertEqual(mapped.label, "RSI")
        XCTAssertEqual(mapped.state, "unavailable")
        XCTAssertNil(mapped.value)
    }

    func testActiveSnapshotDecodesConditionWithNullValue() throws {
        let json = #"{"ok":true,"version":"mobile_v1","data":{"generated_at":"2026-07-18T10:00:00Z","data_source":"real_automation","execution_mode":"real","active_session_count":1,"active_session":{"id":"real-session-001","name":"SOL real","provider":"kraken","provider_label":"Kraken","execution_mode":"real","symbol":"SOLUSDC","display_symbol":"SOL/USDC","quote_asset":"USDC","base_asset":"SOL","status":"active","lifecycle_state":"waiting_buy","strategy_key":"star_v3","strategy_id":"strat-1","strategy_version":"3","strategy_display_name":"Star V3","decision_timeframe":"1m","risk_timeframe":"5m","started_at":"2026-07-18T09:00:00Z","stopped_at":null,"created_at":"2026-07-18T08:59:00Z","updated_at":"2026-07-18T10:00:00Z","monitoring":{"health":"healthy","consecutive_errors":0},"freshness":{"status":"fresh","updated_at":"2026-07-18T09:59:55Z","age_seconds":5},"market":{"current_price":"79.24","quote_asset":"USDC","source":"real_automation","observed_at":"2026-07-18T09:59:50Z","updated_at":"2026-07-18T09:59:55Z"},"decision":{"decision":"waiting_buy","title":"Entrée à confirmer","detail":"Les conditions d'achat ne sont pas encore toutes réunies.","score":"3","score_min":"4","favorable_conditions":3,"required_conditions":4,"controller":"star_v3","blockers":[],"buy_conditions":[{"code":"rsi","label":"RSI","status":"unavailable","value":null}],"sell_conditions":[{"code":"take_profit","label":"Take profit","status":"unavailable","value":null}],"advice":"Attendre confirmation","price":"79.24","created_at":"2026-07-18T09:59:45Z"},"position":null,"active_order":null,"reconciliation":null,"fee_aware":null,"pnl":{"realized_pnl_quote":null,"realized_pnl_net_quote":null,"unrealized_pnl_quote":null,"unrealized_pnl_net_estimated_quote":null}}},"error":null,"meta":{"request_id":"req-contract","server_time":"2026-07-18T10:00:00Z"},"warnings":[]}"#
        let envelope = try JSONCoding.decoder.decode(APIEnvelope<RealActiveSnapshotDTO>.self, from: Data(json.utf8))
        let decision = try XCTUnwrap(envelope.data?.activeSession?.decision)
        let mapped = decision.mapped()
        XCTAssertEqual(mapped.buyConditions.count, 1)
        XCTAssertNil(mapped.buyConditions[0].value)
        XCTAssertEqual(mapped.buyConditions[0].state, "unavailable")
        XCTAssertEqual(mapped.sellConditions.count, 1)
        XCTAssertNil(mapped.sellConditions[0].value)
    }

    func testAuthorizedDevicesItemsPayloadMapsCurrentAndRevokedDevices() throws {
        let data = Data(#"{"items":[{"id":"dev-1","name":"iPhone","model":"iPhone","os_version":"26.5","app_version":"1.0","locale":"fr-FR","created_at":"2026-07-14T10:00:00Z","last_seen_at":null,"last_authenticated_at":"2026-07-14T10:00:00Z","is_current":false,"is_revoked":false},{"id":"dev-2","name":"Ancien iPhone","model":"iPhone","os_version":"25.0","app_version":"1.0","locale":"fr-FR","created_at":"2026-07-10T10:00:00Z","last_seen_at":null,"last_authenticated_at":null,"is_current":false,"is_revoked":true}],"current_device_id":"dev-1"}"#.utf8)
        let dto = try JSONCoding.decoder.decode(AuthorizedDevicesResponseDTO.self, from: data)
        XCTAssertEqual(dto.devices.count, 2)
        XCTAssertTrue(dto.mappedDevices[0].isCurrent)
        XCTAssertTrue(dto.mappedDevices[1].isRevoked)
    }

    func testAuthorizedDevicesEmptyItemsPayloadDecodes() throws {
        let data = Data(#"{"items":[],"current_device_id":null}"#.utf8)
        let dto = try JSONCoding.decoder.decode(AuthorizedDevicesResponseDTO.self, from: data)
        XCTAssertEqual(dto.mappedDevices.count, 0)
    }

    func testAuthorizedDevicesRequiredCollectionMissingStillFails() throws {
        let data = Data(#"{"current_device_id":"dev-1"}"#.utf8)
        XCTAssertThrowsError(try JSONCoding.decoder.decode(AuthorizedDevicesResponseDTO.self, from: data))
    }

}
