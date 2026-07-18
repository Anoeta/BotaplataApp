import SwiftUI

struct DashboardContainerView: View {
    @State var store: ActiveSessionStore
    @Bindable var pushStore: PushNotificationsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    var body: some View {
        DashboardView(
            content: store.content,
            unreadCount: pushStore.unreadCount,
            openAlerts: { router.selectedTab = .dashboard; router.dashboardPath.append("alerts") },
            openSession: { id in router.selectedTab = .sessions; router.sessionsPath.append(SessionRoute.detail(id: id, section: .overview)) },
            refresh: { await store.refresh() }
        )
        .task { store.start(); await pushStore.bootstrap() }
        .navigationDestination(for: String.self) { route in if route == "alerts" { AlertsCenterView(store: pushStore) } }
        .onChange(of: scenePhase) { _, phase in if phase == .background { store.enterBackground() } else if phase == .active { store.enterForeground() } }
    }
}
