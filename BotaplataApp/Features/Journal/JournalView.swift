import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct JournalContainerView: View { @State var historyStore: RealSessionHistoryStore; @State var sessionsStore: RealSessionsStore; @State private var selectedSessionID: String?
    var sessions: [SessionSummary] { sessionsStore.visibleItems }
    var selected: SessionSummary? { sessions.first { $0.id == selectedSessionID } ?? sessions.first { !$0.isHistorical } ?? sessions.first }
    var body: some View { JournalView(session: selected, sessions: sessions, content: selected.map { historyStore.timelines[$0.id] ?? .idle } ?? .loaded([]), warnings: selected.map { historyStore.warnings[$0.id] ?? [] } ?? [], context: .global, select: { selectedSessionID = $0 }, loadNext: { if let id = selected?.id { await historyStore.loadNextTimeline(sessionID: id) } }, refresh: { await sessionsStore.refresh(); if let id = selected?.id { await historyStore.refreshTimeline(sessionID: id) } }).task { await historyStore.loadCache(); sessionsStore.start(); if let id = selected?.id { selectedSessionID = id; await historyStore.refreshTimeline(sessionID: id) } }.onChange(of: selected?.id) { _, id in if let id { selectedSessionID = id; Task { await historyStore.refreshTimeline(sessionID: id) } } } }
}

enum JournalEventCardContext { case global, session }
enum JournalFilter: String, CaseIterable, Identifiable { case all, decisions, orders, positions, system; var id: String { rawValue }; var title: String { switch self { case .all: "Tous"; case .decisions: "Décisions"; case .orders: "Ordres"; case .positions: "Positions"; case .system: "Système" } } }

struct JournalEventPresentation: Equatable { let title: String; let category: JournalFilter; let categoryLabel: String; let icon: String; let status: BadgeStatus; let severityText: String?
    static func make(from event: TimelineEvent) -> Self {
        let category: JournalFilter = switch event.type { case .cycleAnalyzed, .decisionRecorded: .decisions; case .buySubmitted, .buyPartiallyFilled, .buyFilled, .sellSubmitted, .sellPartiallyFilled, .sellFilled, .reconciliationPending, .reconciliationCompleted: .orders; case .positionOpened, .positionClosed: .positions; case .sessionStarted, .sessionStopped, .monitoringDegraded, .error, .unknown: .system }
        let title: String = switch event.type { case .sessionStarted: "Session démarrée"; case .cycleAnalyzed: "Données actualisées"; case .decisionRecorded: "Décision recalculée"; case .buySubmitted: "Ordre d'achat envoyé à Kraken"; case .buyPartiallyFilled: "Ordre d'achat partiellement exécuté"; case .buyFilled: "Achat confirmé par Kraken"; case .positionOpened: "Position ouverte"; case .sellSubmitted: "Ordre de vente envoyé à Kraken"; case .sellPartiallyFilled: "Ordre de vente partiellement exécuté"; case .sellFilled: "Vente confirmée par Kraken"; case .positionClosed: "Position fermée"; case .reconciliationPending: "Vérification de l'ordre nécessaire"; case .reconciliationCompleted: "Vérification terminée"; case .monitoringDegraded: "Surveillance perturbée"; case .sessionStopped: "Session arrêtée"; case .error: "Erreur de surveillance"; case .unknown: event.title }
        let icon: String = switch category { case .decisions: "brain.head.profile"; case .orders: "arrow.up.arrow.down"; case .positions: "chart.line.uptrend.xyaxis"; case .system, .all: "server.rack" }
        let status: BadgeStatus = switch event.severity { case .success: .success; case .warning: .warning; case .danger: .danger; case .neutral: .neutral; case .info: category == .system ? .neutral : .active }
        let severity = event.severity == .warning ? "Attention" : event.severity == .danger ? "Critique" : nil
        return .init(title: title, category: category, categoryLabel: category.title, icon: icon, status: status, severityText: severity)
    }
    static func filtered(_ events: [TimelineEvent], filter: JournalFilter, query: String) -> [TimelineEvent] { events.filter { event in let p = make(from: event); let filterOK = filter == .all || p.category == filter; let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(); guard !q.isEmpty else { return filterOK }; return filterOK && [p.title, event.title, event.message, p.categoryLabel].joined(separator: " ").lowercased().contains(q) } }
}

struct TimelineDateHeader: View { let title: String; var body: some View { Text(title).font(BotaplataTypography.sectionTitle).foregroundStyle(BotaplataColors.textPrimary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, BotaplataSpacing.sm).accessibilityAddTraits(.isHeader) } }

struct JournalView: View { let session: SessionSummary?; let sessions: [SessionSummary]; let content: LoadedContent<[TimelineEvent]>; var warnings: [Warning] = []; var context: JournalEventCardContext = .global; var select: (String) -> Void = { _ in }; var loadNext: () async -> Void = {}; var refresh: () async -> Void = {}; @State private var filter: JournalFilter = .all; @State private var searchText = ""
    var body: some View { ZStack { PremiumBackground(); ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { header; if isOffline { PremiumOfflineBanner(); Text("Dernier état enregistré sur cet iPhone.").font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted) }; ForEach(warnings) { WarningBanner(warning: $0) }; contentView }.padding(BotaplataSpacing.md).safeAreaPadding(.bottom, BotaplataSpacing.xl) } .refreshable { await refresh() } }.navigationTitle("Journal") }
    @ViewBuilder var header: some View { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { HStack { Text("Journal").font(BotaplataTypography.largeTitle).foregroundStyle(BotaplataColors.textPrimary); Spacer(); if !sessions.isEmpty { Menu { ForEach(sessions) { s in Button("\(s.pair) · \(DashboardPresentation.wording(for: s.lifecycle).title)") { select(s.id) } } } label: { StatusPill(status: .active, text: session?.pair ?? "Session") } } }; ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(JournalFilter.allCases) { item in Button { filter = item } label: { FilterPill(title: item.title, isSelected: filter == item) }.buttonStyle(.plain).accessibilityLabel("Filtre Journal \(item.title)") } } }; PremiumSearchField(placeholder: "Rechercher dans les événements chargés", text: $searchText); Text("Recherche dans les événements chargés.").font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted) } }
    @ViewBuilder var contentView: some View { switch content { case .idle, .loading: ForEach(0..<4, id: \.self) { _ in PremiumSkeletonCard() }; case .error: PremiumErrorState(title: "Impossible de charger le Journal", message: "Vérifiez la connexion au serveur Botaplata."); case .loaded(let e), .loadedFromCache(let e), .refreshing(let e?), .offline(let e?), .partial(let e), .stale(let e): timeline(e); case .refreshing(nil), .offline(nil): PremiumErrorState(title: "Impossible de charger le Journal", message: "Vérifiez la connexion au serveur Botaplata.") } }
    @ViewBuilder func timeline(_ events: [TimelineEvent]) -> some View { let visible = JournalEventPresentation.filtered(events, filter: filter, query: searchText); if session == nil { PremiumEmptyState(title: "Aucune session à afficher", message: "Le Journal affichera l'activité de Botaplata lorsqu'une session Kraken réelle sera disponible.") } else if events.isEmpty { PremiumEmptyState(title: "Aucun événement", message: "Les décisions, ordres et événements techniques de Botaplata apparaîtront ici.") } else if visible.isEmpty { PremiumEmptyState(title: "Aucun événement dans ce filtre", message: "Essayez un autre filtre.") } else { ForEach(HistoryPresentation.group(visible), id: \.title) { group in TimelineDateHeader(title: group.title); ForEach(group.items) { event in JournalEventCard(event: event, session: session, context: context).task { if event.id == events.last?.id { await loadNext() } } } } } }
    var isOffline: Bool { if case .offline = content { true } else { false } }
}

struct JournalEventCard: View { let event: TimelineEvent; let session: SessionSummary?; var context: JournalEventCardContext = .global; @State private var expanded = false; private var p: JournalEventPresentation { .make(from: event) }
    var body: some View { Button { expanded.toggle() } label: { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { HStack(alignment: .top) { IconBadge(symbol: p.icon, label: p.categoryLabel, color: p.status.color); Spacer(); Text(HistoryPresentation.time(event.occurredAt)).font(.caption.monospacedDigit()).foregroundStyle(BotaplataColors.textMuted) }; Text(p.title).font(BotaplataTypography.cardTitle).foregroundStyle(BotaplataColors.textPrimary); Text(event.message).font(BotaplataTypography.body).foregroundStyle(BotaplataColors.textSecondary); HStack { if context == .global, let session { Text(session.pair) }; Text(p.categoryLabel); if let severity = p.severityText { Text(severity) } }.font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted); if expanded { EventMetadataRow(title: "Date", value: HistoryPresentation.fullDate(event.occurredAt)); if let id = event.relatedOrderID { EventMetadataRow(title: "Ordre", value: String(id.suffix(8))) } } } } }.buttonStyle(.plain).accessibilityElement(children: .combine).accessibilityLabel("Événement Journal. \(p.title). \(event.message). \(HistoryPresentation.fullDate(event.occurredAt)).") }
}
struct EventMetadataRow: View { let title: String; let value: String; var body: some View { HStack { Text(title).foregroundStyle(BotaplataColors.textMuted); Spacer(); Text(value).foregroundStyle(BotaplataColors.textSecondary).monospacedDigit() }.font(.caption) } }

struct OrdersHistoryView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { PagedHistoryList(title: "Ordres", content: store.orders[session.id] ?? .idle, emptyTitle: "Aucun ordre", emptyMessage: "Aucun ordre n'est disponible pour cette session.", loadNext: { await store.loadNextOrders(sessionID: session.id) }, row: { OrderRow(order: $0) }).task { await store.refreshOrders(sessionID: session.id) }.refreshable { await store.refreshOrders(sessionID: session.id) } } }
struct DecisionsHistoryView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { PagedHistoryList(title: "Décisions", content: store.decisions[session.id] ?? .idle, emptyTitle: "Aucune décision", emptyMessage: "Aucune décision n'est disponible pour cette session.", loadNext: { await store.loadNextDecisions(sessionID: session.id) }, row: { DecisionRow(decision: $0) }).task { await store.refreshDecisions(sessionID: session.id) }.refreshable { await store.refreshDecisions(sessionID: session.id) } } }
struct SessionJournalHistoryView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { JournalView(session: SessionSummary(id: session.id, pair: session.pair, provider: session.provider, providerLabel: session.providerLabel, backendStatus: session.backendStatus, lifecycle: session.lifecycle, runtimeHealth: session.runtimeHealth, freshness: session.freshness, executionMode: session.executionMode), sessions: [], content: store.timelines[session.id] ?? .idle, warnings: store.warnings[session.id] ?? [], context: .session, loadNext: { await store.loadNextTimeline(sessionID: session.id) }, refresh: { await store.refreshTimeline(sessionID: session.id) }).task { await store.refreshTimeline(sessionID: session.id) } } }

struct PagedHistoryList<Item: Identifiable & Sendable, Row: View>: View { let title: String; let content: LoadedContent<[Item]>; let emptyTitle: String; let emptyMessage: String; let loadNext: () async -> Void; let row: (Item) -> Row; var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text(title).font(BotaplataTypography.sectionTitle).accessibilityAddTraits(.isHeader); switch content { case .idle, .loading: ForEach(0..<3, id: \.self) { _ in PremiumSkeletonCard() }; case .error: PremiumErrorState(title: "Chargement impossible", message: "Vérifiez votre connexion puis réessayez."); case .loaded(let items), .loadedFromCache(let items), .refreshing(let items?), .offline(let items?), .partial(let items), .stale(let items): if items.isEmpty { PremiumEmptyState(title: emptyTitle, message: emptyMessage) } else { ForEach(items) { item in row(item).task { if item.id == items.last?.id { await loadNext() } } }; if case .refreshing = content { ProgressView().frame(maxWidth: .infinity) } }; case .refreshing(nil), .offline(nil): PremiumErrorState(title: "Chargement impossible", message: "Vérifiez votre connexion puis réessayez.") } }.padding().safeAreaPadding(.bottom, BotaplataSpacing.xl) } } }
struct OrderRow: View { let order: SessionOrder; var body: some View { BotaplataCard { VStack(alignment: .leading, spacing: 8) { HStack { Text(order.side.label).font(.headline); Spacer(); StatusBadge(status: order.status == .filled ? .success : order.status == .rejected ? .danger : .waiting, text: order.statusLabel ?? order.status.label) }; Text(order.orderType?.uppercased() ?? "Type indisponible").font(.caption).foregroundStyle(BotaplataColors.textSecondary); row("Quantité demandée", order.requestedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Quantité exécutée", order.executedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Prix limite", FinancialFormatters.money(order.limitPrice)); row("Prix moyen exécuté", FinancialFormatters.money(order.averageFillPrice)); row("Montant exécuté", FinancialFormatters.money(order.executedQuoteAmount)); row("Frais", FinancialFormatters.money(order.feesQuote)); row("PnL net réalisé", FinancialFormatters.money(order.realizedPnLNetQuote) == "—" ? "Indisponible" : FinancialFormatters.money(order.realizedPnLNetQuote)); Text(HistoryPresentation.fullDate(order.filledAt ?? order.updatedAt ?? order.createdAt ?? Date())).font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } ; func row(_ k: String, _ v: String) -> some View { PremiumKeyValueRow(label: k, value: v, monospaced: true) } }
struct DecisionRow: View { let decision: SessionDecision; var body: some View { BotaplataCard { VStack(alignment: .leading, spacing: 8) { Text(HistoryPresentation.fullDate(decision.createdAt)).font(.caption).foregroundStyle(BotaplataColors.textSecondary); Text(decision.summaryTitle).font(.headline); Text(decision.summaryMessage).foregroundStyle(BotaplataColors.textSecondary); if let price = decision.price { Text("Prix : \(FinancialFormatters.money(price))").monospacedDigit() }; DisclosureGroup("Voir le détail de l'analyse") { DetailList(title: "Conditions favorables", items: decision.buyConditions); DetailList(title: "Points à vérifier", items: decision.sellConditions + decision.advice); DetailList(title: "Éléments bloquants", items: decision.blockers); if let s = decision.score { Text("Score technique : \(FinancialFormatters.decimal(s, min: 0, max: 4))").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } } } }
struct DetailList: View { let title: String; let items: [String]; var body: some View { if !items.isEmpty { Text(title).font(.subheadline.weight(.semibold)); ForEach(items, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } }

struct SessionChartView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { switch store.charts[session.id] ?? .idle { case .idle, .loading: PremiumSkeletonCard(); case .loaded(let c), .loadedFromCache(let c), .refreshing(let c?), .offline(let c?), .stale(let c): ChartContent(chart: c); case .error: PremiumErrorState(title: "Graphique indisponible", message: "Vérifiez votre connexion puis réessayez."); default: PremiumErrorState(title: "Graphique indisponible", message: "Vérifiez votre connexion puis réessayez.") } }.padding() }.task { await store.refreshChart(sessionID: session.id) }.refreshable { await store.refreshChart(sessionID: session.id) } } }
struct ChartContent: View {
    let chart: SessionChart

    var body: some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            Text(chart.displaySymbol).font(BotaplataTypography.sectionTitle)
            if chart.points.isEmpty {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Graphique en préparation").font(.headline)
                        Text("Le serveur ne fournit pas encore la série de prix nécessaire à l’affichage du graphique.").foregroundStyle(BotaplataColors.textSecondary)
                    }
                }
            } else {
                chartView
            }
            PremiumCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Niveaux financiers").font(.headline)
                    level("Prix moyen exécuté", chart.levels.executionPrice)
                    level("Prix de revient frais inclus", chart.levels.costBasisPrice)
                    level("Seuil de rentabilité", chart.levels.breakEvenPrice)
                    level("Prix minimum rentable", chart.levels.minimumProfitableExitPrice)
                }
            }
            if !chart.markers.isEmpty {
                PremiumCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transactions confirmées").font(.headline)
                        ForEach(chart.markers) { marker in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(marker.label.isEmpty ? marker.type.label : marker.label).font(.headline)
                                Text(HistoryPresentation.fullDate(marker.timestamp)).font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                                Text(FinancialFormatters.money(marker.price)).monospacedDigit()
                                if let quantity = marker.quantity {
                                    Text("\(FinancialFormatters.decimal(quantity, min: 2, max: 8)) \(chart.displaySymbol.split(separator: "/").first.map(String.init) ?? "")")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder var chartView: some View {
        #if canImport(Charts)
        Chart(chart.points) {
            LineMark(x: .value("Date", $0.timestamp), y: .value("Prix", NSDecimalNumber(decimal: $0.price.value ?? 0).doubleValue))
        }
        .frame(height: 220)
        #else
        Text("Courbe disponible sur iOS avec Swift Charts.")
        #endif
    }

    func level(_ title: String, _ amount: MoneyAmount?) -> some View { PremiumKeyValueRow(label: title, value: FinancialFormatters.money(amount), monospaced: true) }
}

enum HistoryPresentation { static func icon(_ e: TimelineEvent) -> String { JournalEventPresentation.make(from: e).icon }; static func color(_ s: TimelineSeverity) -> Color { switch s { case .success: BotaplataColors.success; case .warning: BotaplataColors.warning; case .danger: BotaplataColors.danger; default: BotaplataColors.accent } }; static let timeFormatter: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "fr_FR"); return f }(); static let fullFormatter: DateFormatter = { let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; f.locale = Locale(identifier: "fr_FR"); return f }(); static func time(_ d: Date) -> String { timeFormatter.string(from: d) }; static func fullDate(_ d: Date) -> String { fullFormatter.string(from: d) }; static func group(_ events: [TimelineEvent]) -> [(title: String, items: [TimelineEvent])] { Dictionary(grouping: events) { Calendar.current.isDateInToday($0.occurredAt) ? "Aujourd'hui" : (Calendar.current.isDateInYesterday($0.occurredAt) ? "Hier" : fullDate($0.occurredAt).components(separatedBy: " à ").first ?? fullDate($0.occurredAt)) }.map { ($0.key, $0.value) }.sorted { $0.items.first?.occurredAt ?? .distantPast > $1.items.first?.occurredAt ?? .distantPast } }; static func warning(_ w: Warning) -> String { w.id == "chart_price_series_unavailable" ? "La courbe de prix n'est pas disponible pour cette session." : w.message } }

#Preview("Journal nominal") { NavigationStack { JournalView(session: PreviewFixtures.sessionSummaries.first, sessions: PreviewFixtures.sessionSummaries, content: .loaded(PreviewFixtures.timelineEvents)) } }
#Preview("Journal vide") { NavigationStack { JournalView(session: PreviewFixtures.sessionSummaries.first, sessions: [], content: .loaded([])) } }
#Preview("Journal loading") { NavigationStack { JournalView(session: PreviewFixtures.sessionSummaries.first, sessions: [], content: .loading) } }
#Preview("Événement ordre filled") { JournalEventCard(event: PreviewFixtures.timelineEvents[1], session: PreviewFixtures.sessionSummaries.first).padding().background(BotaplataColors.background) }
#Preview("Graphique sans points") { NavigationStack { ChartContent(chart: PreviewFixtures.sessionChart) } }
#Preview("Ordres") { NavigationStack { PagedHistoryList(title: "Ordres", content: .loaded(PreviewFixtures.sessionOrders), emptyTitle: "Aucun ordre", emptyMessage: "", loadNext: {}, row: { OrderRow(order: $0) }) } }
#Preview("Transactions") { NavigationStack { PagedHistoryList(title: "Transactions", content: .loaded(PreviewFixtures.sessionOrders), emptyTitle: "Aucun ordre", emptyMessage: "", loadNext: {}, row: { OrderRow(order: $0) }) } }
#Preview("Décisions historiques") { NavigationStack { PagedHistoryList(title: "Décisions", content: .loaded(PreviewFixtures.sessionDecisions), emptyTitle: "Aucune décision", emptyMessage: "", loadNext: {}, row: { DecisionRow(decision: $0) }) } }
#Preview("Graphique sans série") { NavigationStack { ChartContent(chart: PreviewFixtures.sessionChart) } }
