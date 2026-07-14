import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(AuthenticationStore.self) private var authStore
    @Environment(ActiveSessionStore.self) private var activeSessionStore

    var body: some View {
        @Bindable var router = router
        Group {
            switch appState.sessionState {
            case .authenticated, .offlineWithCachedSession, .refreshing:
                TabView(selection: $router.selectedTab) {
                    NavigationStack(path: $router.dashboardPath) { DashboardContainerView(store: activeSessionStore) }.tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }.tag(AppTab.dashboard)
                    NavigationStack(path: $router.sessionsPath) { SessionsView(sessions: PreviewFixtures.sessionSummaries) }.tabItem { Label(AppTab.sessions.title, systemImage: AppTab.sessions.symbol) }.tag(AppTab.sessions)
                    NavigationStack(path: $router.journalPath) { JournalView(events: PreviewFixtures.journalEvents) }.tabItem { Label(AppTab.journal.title, systemImage: AppTab.journal.symbol) }.tag(AppTab.journal)
                    NavigationStack(path: $router.profilePath) { ProfileView(profile: PreviewFixtures.profile) }.tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.symbol) }.tag(AppTab.profile)
                }
                .tint(BotaplataColors.accent)
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
            if newState == .loggedOut { Task { await activeSessionStore.purge() } }
        }
    }
}
