import XCTest
@testable import BotaplataApp

struct ControlledBiometricAuthenticator: BiometricAuthenticating {
    var availabilityValue: BiometricAvailability
    var result: BiometricResult
    func availability() async -> BiometricAvailability { availabilityValue }
    func authenticate(reason: String) async -> BiometricResult { result }
}

@MainActor
final class ProfileStoreTests: XCTestCase {
    func testLoadsUserAndDevicesFromAuthenticationSession() async throws {
        let (store, session, _) = makeStore()
        try await session.apply(AuthenticationFixtures.successfulSession)
        await store.bootstrap()
        XCTAssertEqual(store.user?.displayName, AuthenticationFixtures.successfulSession.user.displayName)
        XCTAssertEqual(store.activeDevices.count, 1)
        XCTAssertTrue(store.currentDevice?.isCurrent == true)
    }

    func testBiometricActivationRequiresSuccessfulAuthentication() async throws {
        let (store, _, prefs) = makeStore(bio: ControlledBiometricAuthenticator(availabilityValue: .available, result: .succeeded))
        await store.setBiometricLockEnabled(true)
        XCTAssertTrue(store.biometricLockEnabled)
        XCTAssertTrue(await prefs.biometricLockEnabled())
    }

    func testBiometricCancelledLeavesPreferenceDisabled() async throws {
        let (store, _, prefs) = makeStore(bio: ControlledBiometricAuthenticator(availabilityValue: .available, result: .cancelled))
        await store.setBiometricLockEnabled(true)
        XCTAssertFalse(store.biometricLockEnabled)
        XCTAssertFalse(await prefs.biometricLockEnabled())
    }

    func testAutomaticLockCoordinatorLocksOnlyAfterBackgroundAuthenticatedAndEnabled() {
        let coordinator = LocalBiometricLockCoordinator()
        XCTAssertTrue(coordinator.shouldLock(afterBackground: true, biometricEnabled: true, state: .authenticated))
        XCTAssertFalse(coordinator.shouldLock(afterBackground: false, biometricEnabled: true, state: .authenticated))
        XCTAssertFalse(coordinator.shouldLock(afterBackground: true, biometricEnabled: false, state: .authenticated))
        XCTAssertFalse(coordinator.shouldLock(afterBackground: true, biometricEnabled: true, state: .loggedOut))
        XCTAssertFalse(coordinator.shouldLock(afterBackground: true, biometricEnabled: true, state: .awaitingTwoFactor))
        XCTAssertFalse(coordinator.shouldLock(afterBackground: true, biometricEnabled: true, state: .revoked))
    }

    func testDiagnosticIsSanitized() {
        let diagnostic = ProfileDiagnostic(appVersion: "1.0", build: "1", environment: "Development", isBackendConfigured: true, authenticationState: "authentifiée", biometricState: "disponible")
        let text = diagnostic.sanitizedText.lowercased()
        XCTAssertFalse(text.contains("token"))
        XCTAssertFalse(text.contains("password"))
        XCTAssertFalse(text.contains("totp"))
        XCTAssertFalse(text.contains("kraken"))
        XCTAssertFalse(text.contains("nonce"))
    }

    func testPurgeClearsAuthenticatedProfileData() async throws {
        let (store, session, _) = makeStore()
        try await session.apply(AuthenticationFixtures.successfulSession)
        await store.bootstrap()
        store.purge()
        XCTAssertNil(store.user)
        XCTAssertTrue(store.activeDevices.isEmpty)
    }

    private func makeStore(bio: ControlledBiometricAuthenticator = ControlledBiometricAuthenticator(availabilityValue: .available, result: .succeeded)) -> (ProfileStore, AuthenticationSession, InMemorySecurityPreferencesStore) {
        let state = AppState(sessionState: .authenticated, environment: .development)
        let session = AuthenticationSession(repository: MockAuthenticationRepository(), tokenStore: InMemoryTokenStore())
        let prefs = InMemorySecurityPreferencesStore()
        let store = ProfileStore(authSession: session, appState: state, authenticator: bio, preferences: prefs)
        return (store, session, prefs)
    }
}
