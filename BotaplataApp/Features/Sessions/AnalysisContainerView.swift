import SwiftUI

/// Uses the same authenticated repositories as session detail; no independent signal engine.
struct AnalysisContainerView: View {
    @Bindable var store: RealSessionsStore
    @Environment(RealStrategyExplanationStore.self) private var strategyStore
    @State private var selectedSessionID: String?
    private var selected: SessionSummary? {
        store.visibleItems.first { $0.id == selectedSessionID }
            ?? store.visibleItems.first { !$0.isHistorical }
            ?? store.visibleItems.first
    }
    var body: some View {
        ZStack {
            PremiumScreenBackground()
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Analyse du signal").font(BotaplataTypography.largeTitle).accessibilityAddTraits(.isHeader)
                    if let selected {
                        Menu {
                            ForEach(store.visibleItems) { item in
                                Button("\(item.pair) · Session \(item.id)\(item.isHistorical ? " · Terminée" : "")") { selectedSessionID = item.id }
                            }
                            Button("Charger d’autres sessions") { Task { await store.loadNextPageIfNeeded() } }
                        } label: {
                            HStack {
                                PremiumAssetIcon(pair: selected.pair)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(selected.pair) · Session \(selected.id)").font(.headline)
                                    Text(SessionArchivePresentation.strategy(name: selected.strategyName, version: selected.strategyVersion))
                                        .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain).accessibilityLabel("Choisir la session analysée, \(selected.pair), session \(selected.id)")
                        if selected.isHistorical { PremiumStatusBadge(status: .neutral, text: "Session terminée · analyse enregistrée") }
                    }
                }.padding(.horizontal, 16).padding(.top, 16)
                analysis
            }
        }.navigationTitle("Analyse").navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .task { await store.loadCacheThenRefresh() }
            .task(id: selected?.id) { if let id = selected?.id { await store.loadDetail(id: id) } }
    }
    @ViewBuilder private var analysis: some View {
        if let selected {
            switch store.details[selected.id] ?? .idle {
            case .loaded(let detail), .loadedFromCache(let detail), .refreshing(let detail?), .offline(let detail?), .stale(let detail), .partial(let detail):
                StrategyExplanationSectionView(session: detail, store: strategyStore).id(detail.id)
            case .error(let message):
                PremiumErrorState(title: "Session indisponible", message: message).padding()
                PremiumSecondaryButton(title: "Réessayer") { Task { await store.loadDetail(id: selected.id) } }.padding(.horizontal)
            default: PremiumLoadingSkeleton().padding(); Spacer()
            }
        } else {
            switch store.content {
            case .idle, .loading, .refreshing(nil): PremiumLoadingSkeleton().padding()
            case .error(let message):
                PremiumErrorState(title: "Analyse indisponible", message: message).padding()
                PremiumSecondaryButton(title: "Réessayer") { Task { await store.refresh() } }.padding(.horizontal)
            case .offline(nil): PremiumEmptyState(title: "Hors ligne", message: "Aucune session en cache.", systemImage: "wifi.slash").padding()
            default: PremiumEmptyState(title: "Aucune session à analyser", message: "L’analyse utilise les décisions enregistrées par le backend.", systemImage: "waveform.path.ecg").padding()
            }
            Spacer()
        }
    }
}
