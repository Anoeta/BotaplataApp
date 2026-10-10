#if DEBUG
import SwiftUI

/// Explicit preview composition. These repositories and values never enter the production root.
@MainActor private struct PremiumDashboardPreview: View {
    let offline: Bool
    @State private var chartStore: RealSessionChartStore
    @State private var strategyStore: RealStrategyExplanationStore
    private let snapshot: RealActiveSnapshot
    init(offline: Bool = false) {
        self.offline = offline
        let session = PreviewFixtures.krakenDetail
        snapshot = RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: session, warnings: [], requestID: nil, serverTime: nil)
        let charts = RealSessionChartStore(repository: MockRealSessionChartRepository(), authorize: { work in try await work("BOTAPLATA_PREVIEW_FIXTURE") })
        charts.seedCache(chart: PreviewFixtures.tradingChart(), fetchedAt: Date())
        _chartStore = State(initialValue: charts)
        _strategyStore = State(initialValue: RealStrategyExplanationStore(repository: MockRealStrategyExplanationRepository(), authorize: { work in try await work("BOTAPLATA_PREVIEW_FIXTURE") }))
    }
    var body: some View {
        NavigationStack {
            DashboardView(content: offline ? .offline(snapshot) : .loaded(snapshot))
        }
        .environment(chartStore)
        .environment(strategyStore)
        .preferredColorScheme(.dark)
    }
}

#Preview("V2 · dashboard · fixture explicite") { PremiumDashboardPreview() }
#Preview("V2 · offline · fixture explicite") { PremiumDashboardPreview(offline: true) }
#Preview("V2 · cours · Dynamic Type") {
    PremiumPriceChart(chart: PreviewFixtures.tradingChart(), currentPrice: PreviewFixtures.krakenDetail.currentPrice)
        .padding().background(BotaplataColors.background).dynamicTypeSize(.accessibility3)
}
#Preview("V2 · analyse · fixture explicite") {
    ScrollView { StrategyExplanationContent(explanation: PreviewFixtures.strategyExplanationWait3).padding() }
        .background(BotaplataColors.background)
}
#endif
