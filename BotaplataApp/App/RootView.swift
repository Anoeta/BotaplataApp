import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(AuthenticationStore.self) private var authStore
    @Environment(ActiveSessionStore.self) private var activeSessionStore
    @Environment(RealSessionsStore.self) private var realSessionsStore
    @Environment(RealSessionHistoryStore.self) private var realSessionHistoryStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(PushNotificationsStore.self) private var pushStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var didEnterBackground = false
    private let lockCoordinator = LocalBiometricLockCoordinator()

    init() {
        BotaplataTheme.applyTabBarAppearance()
        BotaplataTheme.applyNavigationAppearance()
    }

    var body: some View {
        @Bindable var router = router
        Group {
            switch appState.sessionState {
            case .authenticated, .offlineWithCachedSession, .refreshing:
                TabView(selection: $router.selectedTab) {
                    NavigationStack(path: $router.dashboardPath) { DashboardContainerView(store: activeSessionStore, pushStore: pushStore) }.tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }.tag(AppTab.dashboard)
                    NavigationStack(path: $router.sessionsPath) { SessionsContainerView(store: realSessionsStore) }.tabItem { Label(AppTab.sessions.title, systemImage: AppTab.sessions.symbol) }.tag(AppTab.sessions)
                    NavigationStack(path: $router.journalPath) { JournalContainerView(historyStore: realSessionHistoryStore, sessionsStore: realSessionsStore) }.tabItem { Label(AppTab.journal.title, systemImage: AppTab.journal.symbol) }.tag(AppTab.journal)
                    NavigationStack(path: $router.profilePath) { ProfileContainerView(store: profileStore, pushStore: pushStore) }.tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.symbol) }.tag(AppTab.profile)
                }
                .tint(BotaplataColors.primaryTeal)
            case .restoring:
                AuthenticationRestoringView()
            case .unknown:
                AuthenticationRestoringView()
            case .loggedOut, .authenticating:
                if authStore.didCompleteOnboarding { LoginView() } else { OnboardingView { authStore.didCompleteOnboarding = true } }
            case .awaitingTwoFactor:
                TwoFactorView()
            case .lockedLocally:
                BiometricLockView(authenticator: LocalAuthenticationBiometricAuthenticator())
            case .revoked:
                DeviceRevokedView()
            case .expired:
                SessionExpiredView()
            }
        }
        .onChange(of: appState.sessionState) { _, newState in
            if [.loggedOut, .revoked, .expired].contains(newState) { Task { await activeSessionStore.purge(); await realSessionsStore.purge(); await realSessionHistoryStore.purge(); await pushStore.purge(); profileStore.purge() } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { didEnterBackground = true }
            if phase == .active {
                if lockCoordinator.shouldLock(afterBackground: didEnterBackground, biometricEnabled: profileStore.biometricLockEnabled, state: appState.sessionState) { authStore.lockLocally() }
                pushStore.applyPendingNavigationIfPossible(router: router); didEnterBackground = false
            }
        }
    }
}
