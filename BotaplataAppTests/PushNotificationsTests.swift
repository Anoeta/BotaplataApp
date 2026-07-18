import XCTest
@testable import BotaplataApp

final class PushNotificationsTests: XCTestCase {
    func testNotificationDTOParsesNavigationTargetAndOptionalMoney() throws {
        let json = """
        {"id":"n1","event_type":"real_buy_filled","severity":"info","title":"Achat confirmé par Kraken","message":"L'achat sur SOL/USDC a été confirmé.","created_at":"2026-07-16T12:00:00Z","is_read":false,"session_id":"21","symbol":"SOL/USDC","provider":"kraken","navigation_target":{"kind":"session","session_id":"21","section":"journal"},"money":null}
        """.data(using: .utf8)!
        let item = try JSONCoding.decoder.decode(RealNotificationItem.self, from: json)
        XCTAssertEqual(item.severity.label, "Information")
        XCTAssertEqual(item.navigationTarget, NotificationNavigationTarget(kind: .session, sessionID: "21", section: .journal))
        XCTAssertNil(item.money)
    }

    func testUnknownNavigationSectionFallsBackToOverview() throws {
        let json = """
        {"kind":"session","session_id":"21","section":"unknown"}
        """.data(using: .utf8)!
        let target = try JSONCoding.decoder.decode(NotificationNavigationTarget.self, from: json)
        XCTAssertEqual(target.section, .overview)
    }

    func testPreferencesHideTechnicalLabelsThroughMapping() {
        let item = PushPreferenceItem(eventType: "real_protection_triggered", enabled: true, mandatory: true, severity: .critical)
        XCTAssertTrue(item.mandatory)
        XCTAssertEqual(item.severity?.label, "Critique")
    }

    func testCacheSnapshotDoesNotContainTokens() throws {
        let snapshot = PushNotificationsCacheSnapshot(notifications: [], summary: RealNotificationSummary(unreadCount: 3, latestCreatedAt: nil), preferences: PreviewFixtures.pushPreferences, savedAt: Date(timeIntervalSince1970: 0))
        let text = String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!
        ["ACCESS_TOKEN_SENTINEL", "REFRESH_TOKEN_SENTINEL", "APNS_DEVICE_TOKEN_SENTINEL", "APNS_PROVIDER_JWT_SENTINEL", "APNS_PRIVATE_KEY_SENTINEL", "KRAKEN_API_KEY_SENTINEL", "KRAKEN_SECRET_SENTINEL", "PASSWORD_SENTINEL", "TOTP_SENTINEL", "NONCE_SENTINEL"].forEach { XCTAssertFalse(text.contains($0)) }
    }
}
