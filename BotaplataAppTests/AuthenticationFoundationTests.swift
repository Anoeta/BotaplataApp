import XCTest
@testable import BotaplataApp

final class AuthenticationFoundationTests: XCTestCase {
    func testMockLoginAndTwoFactorHappyPath() async throws {
        let repo = MockAuthenticationRepository()
        let challenge = try await repo.login(username: "demo", password: "fixture", device: fixtureDevice())
        XCTAssertEqual(challenge.challengeType, "totp")
        let session = try await repo.verifyTwoFactor(challengeID: challenge.id, code: "123456")
        XCTAssertEqual(session.user.displayName, "Utilisateur démo")
    }

    func testMockAuthenticationErrors() async throws {
        let repo = MockAuthenticationRepository(scenario: .invalidCredentials)
        await XCTAssertThrowsAuthentication(.invalidCredentials) { _ = try await repo.login(username: "demo", password: "bad", device: self.fixtureDevice()) }
        await repo.setScenario(.expiredChallenge)
        await XCTAssertThrowsAuthentication(.challengeExpired) { _ = try await repo.verifyTwoFactor(challengeID: "expired", code: "123456") }
        await repo.setScenario(.tooManyAttempts)
        await XCTAssertThrowsAuthentication(.tooManyAttempts) { _ = try await repo.verifyTwoFactor(challengeID: "fixture", code: "123456") }
        await repo.setScenario(.refreshRevoked)
        await XCTAssertThrowsAuthentication(.refreshRevoked) { _ = try await repo.refresh(refreshToken: "fixture-refresh-token-never-production", installationID: "stable-installation") }
        await repo.setScenario(.deviceRevoked)
        await XCTAssertThrowsAuthentication(.deviceRevoked) { _ = try await repo.refresh(refreshToken: "fixture-refresh-token-never-production", installationID: "stable-installation") }
        await repo.logout(accessToken: nil)
    }

    func testInvalidTwoFactorCode() async {
        let repo = MockAuthenticationRepository()
        await XCTAssertThrowsAuthentication(.invalidTwoFactorCode) { _ = try await repo.verifyTwoFactor(challengeID: "fixture", code: "000000") }
    }

    func testInMemoryTokenStore() async throws {
        let store = InMemoryTokenStore(installationID: "stable-installation")
        XCTAssertNil(try await store.readRefreshToken())
        try await store.saveRefreshToken("fixture-refresh-token-never-production")
        XCTAssertEqual(try await store.readRefreshToken(), "fixture-refresh-token-never-production")
        XCTAssertEqual(try await store.installationID(), "stable-installation")
        try await store.saveDeviceID("fixture-device")
        try await store.purgeSession()
        XCTAssertNil(try await store.readRefreshToken())
        XCTAssertNil(try await store.readDeviceID())
    }

    func testAuthenticationSessionRefreshAndLogout() async throws {
        let repo = MockAuthenticationRepository()
        let store = InMemoryTokenStore()
        let session = AuthenticationSession(repository: repo, tokenStore: store)
        try await session.apply(AuthenticationFixtures.successfulSession)
        XCTAssertEqual(await session.accessToken, "fixture-access-token-never-production")
        async let a = session.refresh()
        async let b = session.refresh()
        _ = try await [a, b]
        XCTAssertEqual(await repo.refreshCallCount, 1)
        await session.logout()
        XCTAssertNil(await session.accessToken)
        XCTAssertNil(try await store.readRefreshToken())
    }

    func testAuthenticationSessionPurgesOnRevocation() async throws {
        let repo = MockAuthenticationRepository(scenario: .deviceRevoked)
        let store = InMemoryTokenStore()
        let session = AuthenticationSession(repository: repo, tokenStore: store)
        try await store.saveRefreshToken("fixture-refresh-token-never-production")
        await XCTAssertThrowsAuthentication(.deviceRevoked) { _ = try await session.refresh() }
        XCTAssertNil(try await store.readRefreshToken())
    }

    func testAppStateTransitions() async {
        let state = await AppState(sessionState: .unknown, environment: .debugPreview)
        await XCTAssertTrue(state.transition(to: .restoring))
        await XCTAssertTrue(state.transition(to: .loggedOut))
        await XCTAssertTrue(state.transition(to: .authenticating))
        await XCTAssertTrue(state.transition(to: .awaitingTwoFactor))
        await XCTAssertTrue(state.transition(to: .authenticated))
        await XCTAssertTrue(state.transition(to: .lockedLocally))
        await XCTAssertTrue(state.transition(to: .authenticated))
        await XCTAssertTrue(state.transition(to: .expired))
        await XCTAssertTrue(state.transition(to: .loggedOut))
    }

    func testSecureLoggingRedactsSecrets() {
        let raw = "Authorization: Bearer fixture-access-token-never-production password=supersecret totp=123456 refresh_token=fixture-refresh-token-never-production secret=kraken-secret"
        let sanitized = SecureLogging.sanitized(raw)
        XCTAssertFalse(sanitized.contains("fixture-access-token-never-production"))
        XCTAssertFalse(sanitized.contains("fixture-refresh-token-never-production"))
        XCTAssertFalse(sanitized.contains("supersecret"))
        XCTAssertFalse(sanitized.contains("123456"))
        XCTAssertFalse(sanitized.contains("kraken-secret"))
    }

    func testAPIEnvelopeSuccessAndError() throws {
        struct Payload: Codable, Equatable, Sendable { let value: String }
        let success = APIEnvelope(ok: true, data: Payload(value: "ok"), error: nil, meta: APIMeta(requestID: "example-request-id"), warnings: [APIWarning(code: "W", message: "warning")])
        XCTAssertEqual(success.version, "mobile_v1")
        XCTAssertEqual(success.meta.requestID, "example-request-id")
        XCTAssertEqual(success.warnings.count, 1)
        let failure = APIEnvelope<Payload>(ok: false, data: nil, error: APIErrorPayload(code: "AUTH_INVALID_CREDENTIALS", message: "Identifiant ou mot de passe incorrect.", details: nil, retryable: false), meta: APIMeta(requestID: "example-request-id"))
        XCTAssertNil(failure.data)
        XCTAssertEqual(failure.error?.code, "AUTH_INVALID_CREDENTIALS")
    }

    private func fixtureDevice() -> DeviceFingerprint { DeviceFingerprint(installationID: "fixture-installation-id", name: "iPhone", model: "iPhone", osVersion: "26.5", appVersion: "1.0", locale: "fr-FR") }
}

func XCTAssertThrowsAuthentication(_ expected: AuthenticationError, operation: @escaping () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do { try await operation(); XCTFail("Expected error", file: file, line: line) }
    catch let error as AuthenticationError { XCTAssertEqual(error, expected, file: file, line: line) }
    catch { XCTFail("Unexpected error: \(error)", file: file, line: line) }
}
