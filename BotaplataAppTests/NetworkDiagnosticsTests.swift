import XCTest
@testable import BotaplataApp

final class NetworkDiagnosticsTests: XCTestCase {
    func testEndpointTimeoutPolicyKeepsLocalFailuresShort() {
        XCTAssertEqual(APIEndpointTimeoutPolicy.timeout(for: "/health"), 4)
        XCTAssertEqual(APIEndpointTimeoutPolicy.timeout(for: "/api/mobile/v1/auth/refresh"), 9)
        XCTAssertEqual(APIEndpointTimeoutPolicy.timeout(for: "/api/mobile/v1/auth/login"), 15)
        XCTAssertEqual(APIEndpointTimeoutPolicy.timeout(for: "/api/mobile/v1/real/sessions/42/chart"), 18)
        XCTAssertLessThanOrEqual(APIEndpointTimeoutPolicy.timeout(for: "/api/mobile/v1/real/sessions"), 12)
    }

    func testNetworkDiagnosticHistoryIsBoundedToFiftyEntries() async {
        await NetworkDiagnosticsStore.shared.reset()
        for index in 0..<55 {
            await NetworkDiagnosticsStore.shared.record(NetworkDiagnosticEntry(
                requestID: String(format: "%08d", index),
                method: "GET",
                endpoint: "/api/mobile/v1/real/sessions",
                feature: "Sessions",
                startedAt: Date(),
                duration: 0.1,
                statusCode: 200,
                result: .success,
                cacheStatus: .miss
            ))
        }
        let entries = await NetworkDiagnosticsStore.shared.snapshot()
        XCTAssertLessThanOrEqual(entries.count, 50)
        XCTAssertEqual(entries.first?.requestID, "00000005")
    }

    func testDiagnosticCopyTextDoesNotExposeSecrets() {
        let diagnostic = ProfileDiagnostic(
            appVersion: "1.0",
            build: "1",
            environment: "Development",
            isBackendConfigured: true,
            authenticationState: "non authentifiée",
            biometricState: "Indisponible",
            serverURL: "http://192.168.1.47:31119"
        )
        XCTAssertFalse(diagnostic.sanitizedText.localizedCaseInsensitiveContains("Authorization"))
        XCTAssertFalse(diagnostic.sanitizedText.localizedCaseInsensitiveContains("refresh_token"))
        XCTAssertFalse(diagnostic.sanitizedText.localizedCaseInsensitiveContains("password"))
    }
}
