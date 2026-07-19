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
}
