import XCTest

final class ProductionFixtureAuditTests: XCTestCase {
    func testProductionRootDoesNotUseProfileFixtures() throws {
        let root = try String(contentsOfFile: "BotaplataApp/App/RootView.swift")
        XCTAssertFalse(root.contains("ProfileView(profile: PreviewFixtures.profile)"))
        XCTAssertTrue(root.contains("ProfileContainerView(store: profileStore)"))
    }

    func testDiagnosticCopyShapeDoesNotContainSecretWords() throws {
        let profileStore = try String(contentsOfFile: "BotaplataApp/Features/Profile/ProfileStore.swift")
        XCTAssertFalse(profileStore.contains("refreshToken"))
        XCTAssertFalse(profileStore.contains("accessToken"))
        XCTAssertFalse(profileStore.contains("Authorization"))
        XCTAssertFalse(profileStore.contains("Kraken"))
        XCTAssertFalse(profileStore.contains("nonce"))
    }
}
