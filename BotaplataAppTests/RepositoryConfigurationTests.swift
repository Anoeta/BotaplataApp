import XCTest
@testable import BotaplataApp

final class RepositoryConfigurationTests: XCTestCase {
    func testSnapshotRepositoryDoesNotFallbackToMockWithoutBaseURL() async {
        let development = AppEnvironment(name: "Development", kind: .development, dataSource: .unknown, fixtureSource: nil, isProductionData: false, baseURL: nil)
        let testFlight = AppEnvironment(name: "TestFlight", kind: .testFlight, dataSource: .unknown, fixtureSource: nil, isProductionData: true, baseURL: nil)
        let production = AppEnvironment(name: "Production", kind: .production, dataSource: .unknown, fixtureSource: nil, isProductionData: true, baseURL: nil)
        for environment in [development, testFlight, production] {
            await XCTAssertThrowsAuthentication(.notConfigured) {
                _ = try await BotaplataApp.makeSnapshotRepository(environment: environment).fetchActiveSnapshot(accessToken: "token")
            }
        }
    }

    func testPreviewAndUITestingAreExplicitMockContexts() async throws {
        let snapshot = try await MockRealActiveSnapshotRepository().fetchActiveSnapshot(accessToken: "token")
        XCTAssertEqual(snapshot.requestID, "preview")
        XCTAssertEqual(AppEnvironment.debugPreview.kind, .preview)
        XCTAssertEqual(AppEnvironment.uiTesting.kind, .uiTesting)
    }
}
