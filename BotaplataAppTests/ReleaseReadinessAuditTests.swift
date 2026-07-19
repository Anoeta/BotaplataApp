import XCTest

final class ReleaseReadinessAuditTests: XCTestCase {
    private let auditedRoots = ["BotaplataApp", "BotaplataApp.xcodeproj"]
    private let releaseSourceRoots = ["BotaplataApp", "BotaplataApp.xcodeproj"]
    private let allowedLocalDevelopmentURL = "http://192.168.x.x:31119"

    func testProductionAndTestFlightHaveNoLocalBaseURLFallback() throws {
        let environment = try file("BotaplataApp/App/AppEnvironment.swift")
        XCTAssertFalse(environment.contains(allowedLocalDevelopmentURL))
        XCTAssertTrue(environment.contains("Bundle.main.botaplataNetworkConfiguration"))
        XCTAssertTrue(try file("BotaplataApp/Core/Configuration/NetworkConfiguration.swift").contains("BOTAPLATA_NETWORK_ENVIRONMENT"))
    }

    func testMocksAreLimitedToUITestsPreviewsAndExplicitDebugDemo() throws {
        let app = try file("BotaplataApp/App/BotaplataApp.swift")
        XCTAssertTrue(app.contains("let usesFixtures = isUITesting || isExplicitDemo"))
        XCTAssertTrue(app.contains("--botaplata-demo-authenticated"))
        XCTAssertTrue(app.contains("BOTAPLATA_DEBUG_DEMO"))
        XCTAssertFalse(app.contains("botaplata-demo-authenticated") && app.contains("#else\n        let isExplicitDemo = true"))
    }

    func testAuthReplayIsSharedByReleaseStores() throws {
        for path in [
            "BotaplataApp/Features/Dashboard/ActiveSessionStore.swift",
            "BotaplataApp/Features/Sessions/RealSessionsStore.swift",
            "BotaplataApp/Features/Sessions/RealSessionHistoryStore.swift",
            "BotaplataApp/Features/Profile/ProfileStore.swift",
            "BotaplataApp/Features/PushNotifications/PushNotificationsStore.swift"
        ] {
            XCTAssertTrue(try file(path).contains("withAccessTokenReplay"), "\(path) must use AuthenticationSession.withAccessTokenReplay")
        }
    }

    func testNoGlobalATSBypassOrAppleSecretFiles() throws {
        for path in try allFiles(roots: auditedRoots) {
            XCTAssertFalse(path.hasSuffix(".p8"), "APNs private keys must never be committed: \(path)")
            let contents = try file(path)
            XCTAssertFalse(contents.contains("NSAllowsArbitraryLoads"), "No global ATS bypass in \(path)")
            XCTAssertFalse(contents.contains("NSExceptionDomains"), "No ATS exception domains in \(path)")
        }
    }

    func testNoSentinelSecretsOrExchangeDirectCallsInReleaseSources() throws {
        let forbidden = [
            "ACCESS_TOKEN_SENTINEL", "REFRESH_TOKEN_SENTINEL", "APNS_DEVICE_TOKEN_SENTINEL", "APNS_PROVIDER_JWT_SENTINEL",
            "APNS_PRIVATE_KEY_SENTINEL", "KRAKEN_API_KEY_SENTINEL", "KRAKEN_SECRET_SENTINEL", "BINANCE_API_KEY_SENTINEL",
            "BINANCE_SECRET_SENTINEL", "PASSWORD_SENTINEL", "TOTP_SENTINEL", "NONCE_SENTINEL",
            "api.kraken.com", "api.binance.com"
        ]
        for path in try allFiles(roots: releaseSourceRoots) {
            let contents = try file(path)
            for needle in forbidden { XCTAssertFalse(contents.contains(needle), "Forbidden value \(needle) in \(path)") }
        }
    }

    private func file(_ path: String) throws -> String { try String(contentsOfFile: path) }
    private func allFiles(roots: [String]) throws -> [String] {
        var files: [String] = []
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(atPath: root) else { continue }
            for case let path as String in enumerator where !path.contains("xcuserdata") {
                let full = "\(root)/\(path)"
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: full, isDirectory: &isDirectory), !isDirectory.boolValue { files.append(full) }
            }
        }
        return files
    }
}
