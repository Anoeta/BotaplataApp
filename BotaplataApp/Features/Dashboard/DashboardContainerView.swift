import SwiftUI

struct DashboardContainerView: View {
    @State var store: ActiveSessionStore
    @Bindable var pushStore: PushNotificationsStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppRouter.self) private var router
    @Environment(RealStrategyExplanationStore.self) private var strategyStore
    @Environment(RealSessionChartStore.self) private var chartStore
    @Environment(RealSessionHistoryStore.self) private var historyStore
    var body: some View {
        DashboardView(
            content: store.content,
            unreadCount: pushStore.unreadCount,
            openAlerts: { router.selectedTab = .dashboard; router.dashboardPath.append("alerts") },
            openSession: { id in router.selectedTab = .sessions; router.sessionsPath.append(SessionRoute.detail(id: id, section: .overview)) },
            refresh: {
                await store.refresh(reason: .manualRefresh, force: true)
                if let id = sessionID {
                    await strategyStore.refresh(sessionID: id)
                    chartStore.refresh(sessionID: id)
                }
            },
            historyStore: historyStore,
            openAnalysis: { id in router.selectedTab = .sessions; router.sessionsPath.append(SessionRoute.detail(id: id, section: .analysis)) }
        )
        .task { store.start() }
        .task(id: analysisActivityKey) {
            guard scenePhase == .active, let id = sessionID else { return }
            do {
                while !Task.isCancelled {
                    await strategyStore.load(sessionID: id, reason: "dashboardVisible")
                    try await Task.sleep(for: .seconds(30))
                }
            } catch { }
        }
        .onDisappear {
            store.stop()
            if let id = sessionID { strategyStore.cancel(sessionID: id) }
        }
        .navigationDestination(for: String.self) { route in if route == "alerts" { AlertsCenterView(store: pushStore).toolbar(.visible, for: .navigationBar) } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { store.enterBackground(); if let id = sessionID { strategyStore.cancel(sessionID: id) } } else if phase == .active { store.enterForeground() } }
    }
    private var sessionID: String? {
        switch store.content {
        case .loaded(let s), .partial(let s), .loadedFromCache(let s), .stale(let s), .refreshing(let s?), .offline(let s?): s.activeSession?.id
        default: nil
        }
    }
    private var analysisActivityKey: String { "\(sessionID ?? "none"):\(scenePhase == .active)" }
}
