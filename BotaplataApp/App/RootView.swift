import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        Group {
            switch appState.sessionState {
            case .authenticated, .offlineWithCachedSession, .refreshing:
                TabView(selection: $router.selectedTab) {
                    NavigationStack(path: $router.dashboardPath) { DashboardView(summary: PreviewFixtures.dashboardNominalKraken) }.tabItem { Label(AppTab.dashboard.title, systemImage: AppTab.dashboard.symbol) }.tag(AppTab.dashboard)
                    NavigationStack(path: $router.sessionsPath) { SessionsView(sessions: PreviewFixtures.sessionSummaries) }.tabItem { Label(AppTab.sessions.title, systemImage: AppTab.sessions.symbol) }.tag(AppTab.sessions)
                    NavigationStack(path: $router.journalPath) { JournalView(events: PreviewFixtures.journalEvents) }.tabItem { Label(AppTab.journal.title, systemImage: AppTab.journal.symbol) }.tag(AppTab.journal)
                    NavigationStack(path: $router.profilePath) { ProfileView(profile: PreviewFixtures.profile) }.tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.symbol) }.tag(AppTab.profile)
                }
                .tint(BotaplataColors.accent)
            case .restoring:
                LoadingStateView(title: "Restauration", message: "Préparation du dernier état connu.")
            case .loggedOut, .unknown, .authenticating, .awaitingTwoFactor, .lockedLocally, .revoked, .expired:
                AuthenticationPlaceholderView(state: appState.sessionState)
            }
        }
    }
}
