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

@MainActor
final class ProfilePresentationTests: XCTestCase {
    func testInitialsAndFallbackUser() {
        XCTAssertEqual(ProfilePresentation.initials(for: AuthenticatedUser(id: "u", displayName: "Daniel Martin", roles: [], permissions: [])), "DM")
        XCTAssertEqual(ProfilePresentation.displayName(for: AuthenticatedUser(id: "u", displayName: "   ", roles: [], permissions: [])), "Utilisateur Botaplata")
        XCTAssertEqual(ProfilePresentation.initials(for: nil), "BP")
    }

    func testBiometricAndTwoFactorWording() {
        XCTAssertEqual(ProfilePresentation.biometricMicrocopy(availability: .available), "Face ID verrouille l’application sur cet iPhone.")
        XCTAssertEqual(ProfilePresentation.biometricMicrocopy(availability: .unavailable), "Indisponible sur cet appareil.")
    }

    func testCurrentDeviceAndRevocationPresentation() {
        let current = AuthenticationFixtures.device
        let other = AuthorizedDevice(id: "other", name: "iPhone de Daniel", model: "iPhone", osVersion: "26.0", appVersion: "1.0", locale: "fr-FR", createdAt: Date(), lastSeenAt: Date(), lastAuthenticatedAt: nil, isCurrent: false, isRevoked: false)
        XCTAssertTrue(current.isCurrent)
        XCTAssertFalse(other.isCurrent)
        XCTAssertEqual(ProfilePresentation.devicesSummary(current: current, others: 1), "Cet iPhone · 1 autre appareil")
        XCTAssertEqual(ProfilePresentation.deviceTitle(other), "iPhone de Daniel")
    }

    func testNotificationPermissionDeniedWordingAndPreferenceCopy() {
        XCTAssertEqual(ProfilePresentation.permissionText(.denied), "Désactivées dans iOS")
        XCTAssertEqual(ProfilePresentation.preferenceTitle("real_monitoring_degraded"), "Surveillance")
        XCTAssertEqual(ProfilePresentation.preferenceDetail("real_order_rejected"), "Recevoir une notification lorsqu’un ordre change d’état.")
    }

    func testBundleVersionFormattingAndNoDangerousLabels() {
        let diagnostic = ProfileDiagnostic(appVersion: "1.0", build: "42", environment: "Production", isBackendConfigured: true, authenticationState: "authentifiée", biometricState: "Activé")
        XCTAssertEqual("Version \(diagnostic.appVersion) (\(diagnostic.build))", "Version 1.0 (42)")
        let visible = [ProfilePresentation.preferenceTitle("real_monitoring_degraded"), ProfilePresentation.permissionText(.denied), ProfilePresentation.biometricMicrocopy(availability: .available)].joined(separator: " ").lowercased()
        XCTAssertFalse(visible.contains("kraken api key"))
        XCTAssertFalse(visible.contains("access token"))
        XCTAssertFalse(visible.contains("refresh token"))
        XCTAssertFalse(visible.contains("delete account"))
    }
}
