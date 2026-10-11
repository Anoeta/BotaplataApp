#if DEBUG
import SwiftUI

enum MidnightPreviewScenario: String, CaseIterable {
    case home, sessions, detail, analysis, orders, journal, profile, offline, empty, error, loading
}

enum MidnightPreviewData {
    static var session: SessionDetail {
        var value = PreviewFixtures.krakenDetail
        value.backendStatus = "running"
        value.strategyName = "Star V3"
        value.strategyVersion = "3.2"
        value.startedAt = PreviewFixtures.now.addingTimeInterval(-7200)
        value.priceObservedAt = PreviewFixtures.now
        return value
    }
    static var sessions: [SessionSummary] {
        var items = PreviewFixtures.sessionSummaries
        if !items.isEmpty { items[0].backendStatus = "running"; items[0].strategyName = "Star V3"; items[0].strategyVersion = "3.2" }
        return items
    }
}

/// Explicitly isolated fixtures, shared by previews and Xcode rendering tests.
@MainActor struct MidnightPreviewScreen: View {
    let scenario: MidnightPreviewScenario
    @State private var chartStore: RealSessionChartStore
    @State private var strategyStore: RealStrategyExplanationStore
    private var snapshot: RealActiveSnapshot {
        RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: MidnightPreviewData.session, warnings: [], requestID: nil, serverTime: nil)
    }
    init(scenario: MidnightPreviewScenario) {
        self.scenario = scenario
        let charts = RealSessionChartStore(repository: MockRealSessionChartRepository(), authorize: { work in try await work("BOTAPLATA_PREVIEW_FIXTURE") })
        charts.seedCache(chart: PreviewFixtures.tradingChart(), fetchedAt: Date())
        charts.load(sessionID: PreviewFixtures.krakenDetail.id)
        _chartStore = State(initialValue: charts)
        let strategy = RealStrategyExplanationStore(repository: MockRealStrategyExplanationRepository(), authorize: { work in try await work("BOTAPLATA_PREVIEW_FIXTURE") })
        _strategyStore = State(initialValue: strategy)
    }
    var body: some View {
        ZStack {
            PremiumScreenBackground()
            NavigationStack { screen }
        }
        .environment(chartStore).environment(strategyStore)
        .safeAreaInset(edge: .top) {
            Text("FIXTURE DE PREVIEW · DONNÉES FICTIVES").font(.caption.weight(.semibold))
                .foregroundStyle(BotaplataColors.warning).padding(8)
                .frame(maxWidth: .infinity).background(BotaplataColors.surface)
        }
    }
    @ViewBuilder private var screen: some View {
        switch scenario {
        case .home: DashboardView(content: .loaded(snapshot))
        case .offline: DashboardView(content: .offline(snapshot))
        case .empty: DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 0, activeSession: nil, warnings: [], requestID: nil, serverTime: nil)))
        case .error: DashboardView(content: .error("Le serveur de cette fixture est indisponible."))
        case .loading: DashboardView(content: .loading)
        case .sessions: SessionsView(content: .loaded(MidnightPreviewData.sessions))
        case .detail: SessionDetailView(session: MidnightPreviewData.session)
        case .analysis:
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Analyse du signal").font(BotaplataTypography.largeTitle)
                    StrategyExplanationContent(explanation: PreviewFixtures.strategyExplanationWait3)
                }.padding(16)
            }
        case .orders: OrdersView(content: .loaded(PreviewFixtures.sessionOrders))
        case .journal: JournalView(session: PreviewFixtures.sessionSummaries.first, sessions: PreviewFixtures.sessionSummaries, content: .loaded(PreviewFixtures.timelineEvents))
        case .profile: ProfileView(store: .preview(), pushStore: .preview(), lockNow: {}, logout: {})
        }
    }
}

#Preview("V3 · Accueil · fixture") { MidnightPreviewScreen(scenario: .home).preferredColorScheme(.dark) }
#Preview("V3 · Sessions · fixture") { MidnightPreviewScreen(scenario: .sessions).preferredColorScheme(.dark) }
#Preview("V3 · Session · fixture") { MidnightPreviewScreen(scenario: .detail).preferredColorScheme(.dark) }
#Preview("V3 · Analyse · fixture") { MidnightPreviewScreen(scenario: .analysis).preferredColorScheme(.dark) }
#Preview("V3 · Ordres · fixture") { MidnightPreviewScreen(scenario: .orders).preferredColorScheme(.dark) }
#Preview("V3 · Journal · fixture") { MidnightPreviewScreen(scenario: .journal).preferredColorScheme(.dark) }
#Preview("V3 · Profil · fixture") { MidnightPreviewScreen(scenario: .profile).preferredColorScheme(.dark) }
#Preview("V3 · Hors ligne · fixture") { MidnightPreviewScreen(scenario: .offline).preferredColorScheme(.dark) }
#Preview("V3 · Données absentes · fixture") { MidnightPreviewScreen(scenario: .empty).preferredColorScheme(.dark) }
#Preview("V3 · Petit écran · grand texte") { MidnightPreviewScreen(scenario: .sessions).dynamicTypeSize(.accessibility3).preferredColorScheme(.dark) }
#Preview("V3 · Clair · fixture") { MidnightPreviewScreen(scenario: .home).preferredColorScheme(.light) }
#Preview("V3 · Chandeliers · fixture") {
    ScrollView { PremiumChartContainer(title: "SOL/USDC · fixture", subtitle: "Bougies persistées · 1 min") { PremiumCandlestickPanel(chart: PreviewFixtures.tradingChart(), currentPrice: PreviewFixtures.krakenDetail.currentPrice) }.padding() }
        .background(BotaplataColors.background).preferredColorScheme(.dark)
}
#Preview("V3 · P&L absent") { PremiumPerformanceUnavailableCard().padding().background(BotaplataColors.background).preferredColorScheme(.dark) }
#Preview("V3 · Timeline · fixture") { PremiumRecentEventsCard(content: .loaded(PreviewFixtures.timelineEvents)).padding().background(BotaplataColors.background).preferredColorScheme(.dark) }
#Preview("V3 · Navigation native") {
    PremiumBottomNavigation(selection: .constant(.dashboard)) {
        ForEach(AppTab.allCases, id: \.self) { tab in
            NavigationStack { Text(tab.title).frame(maxWidth: .infinity, maxHeight: .infinity).background(BotaplataColors.background) }
                .tabItem { Label(tab.title, systemImage: tab.symbol) }.tag(tab)
        }
    }.preferredColorScheme(.dark)
}
#endif
