import SwiftUI

struct PremiumSessionMetricsGrid: View {
    let session: SessionDetail
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var realized: MoneyAmount? { session.pnl?.realizedNet ?? session.pnl?.realizedGross }
    private var latent: MoneyAmount? { session.pnl?.netEstimated ?? session.feeAware.unrealizedPnLNetEstimatedQuote }
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), alignment: .leading, spacing: 12) {
            PremiumMetricCard(title: session.pnl?.realizedNet?.value == nil ? "Réalisé brut" : "Réalisé net", value: FinancialFormatters.money(realized), footnote: session.pnl?.realizedNet?.value == nil ? "Net de frais non certifié" : "Fourni par le backend", tone: .pnl(realized), symbol: "checkmark.circle")
            PremiumMetricCard(title: "Latent net estimé", value: FinancialFormatters.money(latent), footnote: "Estimation de sortie", tone: .pnl(latent), symbol: "chart.line.uptrend.xyaxis")
            PremiumMetricCard(title: "Valeur de position", value: FinancialFormatters.money(session.position?.estimatedValueQuote), footnote: "Valeur estimée", symbol: "square.stack.3d.up")
            PremiumMetricCard(title: "Frais d’achat", value: FinancialFormatters.money(session.feeAware.buyFeeQuote), footnote: "Frais constatés", symbol: "receipt")
        }
    }
}

/// The chart API exposes market OHLC, not portfolio equity or a historical P&L series.
struct PremiumPerformanceUnavailableCard: View {
    var body: some View {
        PremiumCard {
            Label("Courbe de performance", systemImage: "chart.xyaxis.line").font(BotaplataTypography.cardTitle)
            Text("Indisponible").font(.title3.weight(.semibold))
            Text("Le backend ne fournit pas de série de valorisation ou de P&L. Le graphique de marché représente le prix de l’actif.")
                .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
        }.accessibilityElement(children: .combine)
    }
}

struct PremiumRecentEventsSection: View {
    let sessionID: String
    @Bindable var store: RealSessionHistoryStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        PremiumRecentEventsCard(content: store.timelines[sessionID] ?? .idle)
            .task(id: "\(sessionID):\(scenePhase == .active)") {
                if scenePhase == .active {
                    if store.timelines[sessionID] == nil { await store.loadCache() }
                    await store.refreshTimeline(sessionID: sessionID)
                }
            }
    }
}

struct PremiumRecentEventsCard: View {
    let content: LoadedContent<[TimelineEvent]>
    var body: some View {
        PremiumCard {
            PremiumSectionHeader(title: "Derniers événements", subtitle: "Événements enregistrés par le backend")
            switch content {
            case .idle, .loading, .refreshing(nil): ProgressView("Chargement du journal…").frame(minHeight: 44)
            case .error(let message): Text(message).font(.caption).foregroundStyle(BotaplataColors.warning)
            case .offline(nil): Text("Journal indisponible hors ligne").font(.caption).foregroundStyle(BotaplataColors.warning)
            case .loaded(let events), .loadedFromCache(let events), .refreshing(let events?), .offline(let events?), .stale(let events), .partial(let events):
                if case .offline = content { Text("Événements en cache").font(.caption).foregroundStyle(BotaplataColors.warning) }
                if case .loadedFromCache = content { Text("Événements en cache").font(.caption).foregroundStyle(BotaplataColors.textSecondary) }
                if events.isEmpty { Text("Aucun événement fourni").font(.subheadline).foregroundStyle(BotaplataColors.textSecondary) }
                ForEach(Array(events.sorted { $0.occurredAt > $1.occurredAt }.prefix(3))) { event in
                    let presentation = JournalEventPresentation.make(from: event)
                    PremiumTimelineRow(symbol: presentation.icon, color: presentation.status.color, date: event.occurredAt) {
                        Text(event.title).font(.subheadline.weight(.semibold))
                        Text(event.message).font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                    }.accessibilityElement(children: .combine)
                }
            }
        }
    }
}
