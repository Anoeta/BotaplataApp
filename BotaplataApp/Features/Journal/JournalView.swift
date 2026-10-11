import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct JournalContainerView: View {
    @State var historyStore: RealSessionHistoryStore
    @State var sessionsStore: RealSessionsStore
    @State private var selectedSessionID: String?
    private var sessions: [SessionSummary] { sessionsStore.visibleItems }
    private var selected: SessionSummary? { sessions.first { $0.id == selectedSessionID } ?? sessions.first { !$0.isHistorical } ?? sessions.first }
    var body: some View {
        JournalView(
            session: selected, sessions: sessions,
            content: selected.map { historyStore.timelines[$0.id] ?? .idle } ?? .loaded([]),
            warnings: selected.map { historyStore.warnings[$0.id] ?? [] } ?? [],
            select: { selectedSessionID = $0 },
            loadNext: { if let id = selected?.id { await historyStore.loadNextTimeline(sessionID: id) } },
            refresh: { await sessionsStore.refresh(); if let id = selected?.id { await historyStore.refreshTimeline(sessionID: id) } },
            hasMore: selected.flatMap { historyStore.timelinePagination[$0.id]?.hasMore } ?? false
        )
        .task { await historyStore.loadCache(); sessionsStore.start() }
        .task(id: selected?.id) { if let id = selected?.id { await historyStore.refreshTimeline(sessionID: id) } }
        .navigationDestination(for: SessionRoute.self) { route in
            switch route {
            case let .detail(id, section):
                SessionDetailContainerView(sessionID: id, initialSection: section, content: sessionsStore.details[id] ?? .idle, load: { await sessionsStore.loadDetail(id: id) }, historyStore: historyStore)
            }
        }
    }
}

enum JournalEventCardContext { case global, session }
enum JournalFilter: String, CaseIterable, Identifiable { case all, decisions, orders, positions, system, errors; var id: String { rawValue }; var title: String { switch self { case .all: "Tous"; case .decisions: "Signaux"; case .orders: "Ordres"; case .positions: "Positions"; case .system: "Système"; case .errors: "Erreurs" } } }

struct JournalEventPresentation: Equatable { let title: String; let category: JournalFilter; let categoryLabel: String; let icon: String; let status: BadgeStatus; let severityText: String?
    static func make(from event: TimelineEvent) -> Self {
        let category: JournalFilter = switch event.type { case .cycleAnalyzed, .decisionRecorded: .decisions; case .buySubmitted, .buyPartiallyFilled, .buyFilled, .sellSubmitted, .sellPartiallyFilled, .sellFilled, .reconciliationPending, .reconciliationCompleted: .orders; case .positionOpened, .positionClosed: .positions; case .sessionStarted, .sessionStopped, .monitoringDegraded, .error, .unknown: .system }
        let title: String = switch event.type { case .sessionStarted: "Session démarrée"; case .cycleAnalyzed: "Cycle d’analyse"; case .decisionRecorded: "Décision enregistrée"; case .buySubmitted: "Ordre d'achat envoyé à Kraken"; case .buyPartiallyFilled: "Ordre d'achat partiellement exécuté"; case .buyFilled: "Achat confirmé par Kraken"; case .positionOpened: "Position ouverte"; case .sellSubmitted: "Ordre de vente envoyé à Kraken"; case .sellPartiallyFilled: "Ordre de vente partiellement exécuté"; case .sellFilled: "Vente confirmée par Kraken"; case .positionClosed: "Position fermée"; case .reconciliationPending: "Vérification de l'ordre nécessaire"; case .reconciliationCompleted: "Vérification terminée"; case .monitoringDegraded: "Surveillance perturbée"; case .sessionStopped: "Session arrêtée"; case .error: "Erreur de surveillance"; case .unknown: event.title }
        let icon: String = switch category { case .decisions: "brain.head.profile"; case .orders: "arrow.up.arrow.down"; case .positions: "chart.line.uptrend.xyaxis"; case .system, .all: "server.rack"; case .errors: "exclamationmark.triangle" }
        let status: BadgeStatus = switch event.severity { case .success: .success; case .warning: .warning; case .danger: .danger; case .neutral: .neutral; case .info: category == .system ? .neutral : .active }
        let severity = event.severity == .warning ? "Attention" : event.severity == .danger ? "Critique" : nil
        return .init(title: title, category: category, categoryLabel: category.title, icon: icon, status: status, severityText: severity)
    }
    static func filtered(_ events: [TimelineEvent], filter: JournalFilter, query: String) -> [TimelineEvent] { events.filter { event in let p = make(from: event); let filterOK = filter == .all || p.category == filter || (filter == .errors && (event.type == .error || event.severity == .danger)); let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(); guard !q.isEmpty else { return filterOK }; return filterOK && [p.title, event.title, event.message, p.categoryLabel].joined(separator: " ").lowercased().contains(q) } }
}

struct TimelineDateHeader: View { let title: String; var body: some View { Text(title).font(BotaplataTypography.sectionTitle).foregroundStyle(BotaplataColors.textPrimary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, BotaplataSpacing.sm).accessibilityAddTraits(.isHeader) } }

struct JournalView: View {
    let session: SessionSummary?
    let sessions: [SessionSummary]
    let content: LoadedContent<[TimelineEvent]>
    var warnings: [Warning] = []
    var context: JournalEventCardContext = .global
    var select: (String) -> Void = { _ in }
    var loadNext: () async -> Void = {}
    var refresh: () async -> Void = {}
    var hasMore = false
    @State private var filter: JournalFilter = .all
    @State private var searchText = ""
    private var isOffline: Bool { if case .offline = content { true } else { false } }
    var body: some View {
        ZStack {
            PremiumScreenBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    header
                    if isOffline { PremiumOfflineBanner() }
                    ForEach(warnings) { WarningBanner(warning: $0) }
                    contentView
                    if hasMore { PremiumSecondaryButton(title: "Charger d’autres événements") { Task { await loadNext() } } }
                }.padding(16).safeAreaPadding(.bottom, 16)
            }.refreshable { await refresh() }
        }.navigationTitle("Journal").navigationBarTitleDisplayMode(.inline)
            .toolbar(context == .global ? .hidden : .visible, for: .navigationBar)
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Journal").font(BotaplataTypography.largeTitle).accessibilityAddTraits(.isHeader)
            if !sessions.isEmpty {
                Menu {
                    ForEach(sessions) { item in Button("\(item.pair) · Session \(item.id) · \(SessionsPresentation.statusText(item))") { select(item.id) } }
                } label: {
                    HStack { Text("\(session?.pair ?? "Session") · \(session?.id ?? "")"); Image(systemName: "chevron.down") }.frame(minHeight: 44)
                }.accessibilityLabel("Choisir la session du journal")
            }
            PremiumSegmentedControl(title: "Journal", options: [.all, .decisions, .system, .errors], selection: $filter, label: { $0.title })
            Menu("Filtres détaillés") {
                Button("Ordres") { filter = .orders }
                Button("Positions") { filter = .positions }
                Button("Tous les événements") { filter = .all }
            }.font(.subheadline).frame(minHeight: 44)
            if filter == .orders || filter == .positions { PremiumStatusBadge(status: .neutral, text: "Filtre : \(filter.title)") }
            PremiumSearchField(placeholder: "Rechercher dans les événements chargés", text: $searchText)
        }.foregroundStyle(BotaplataColors.textPrimary)
    }
    @ViewBuilder private var contentView: some View {
        switch content {
        case .idle, .loading, .refreshing(nil): PremiumLoadingSkeleton(); PremiumLoadingSkeleton()
        case .error(let message): PremiumErrorState(title: "Journal indisponible", message: message)
        case .offline(nil): PremiumEmptyState(title: "Journal hors ligne", message: "Aucun événement en cache.", systemImage: "wifi.slash")
        case .loaded(let events), .loadedFromCache(let events), .refreshing(let events?), .offline(let events?), .partial(let events), .stale(let events): timeline(events)
        }
    }
    @ViewBuilder private func timeline(_ events: [TimelineEvent]) -> some View {
        let visible = JournalEventPresentation.filtered(events, filter: filter, query: searchText)
        if session == nil { PremiumEmptyState(title: "Aucune session", message: "Choisissez une session réelle pour consulter ses événements.") }
        else if events.isEmpty { PremiumEmptyState(title: "Aucun événement", message: "Aucun événement n’a été fourni pour cette session.") }
        else if visible.isEmpty { PremiumEmptyState(title: "Aucun résultat dans les événements chargés", message: "Changez le filtre ou chargez la suite du journal.") }
        else {
            ForEach(HistoryPresentation.group(visible), id: \.title) { group in
                TimelineDateHeader(title: group.title)
                PremiumCard {
                    ForEach(group.items.sorted { $0.occurredAt > $1.occurredAt }) { event in
                        JournalEventCard(event: event, session: session, context: context)
                    }
                }
            }
        }
    }
}

struct JournalEventCard: View {
    let event: TimelineEvent
    let session: SessionSummary?
    var context: JournalEventCardContext = .global
    @State private var expanded = false
    private var presentation: JournalEventPresentation { .make(from: event) }
    var body: some View {
        Button { expanded.toggle() } label: {
            PremiumTimelineRow(symbol: presentation.icon, color: presentation.status.color, date: event.occurredAt) {
                Text(event.title).font(.headline)
                Text(event.message).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary)
                if let severity = presentation.severityText { Text(severity).font(.caption.weight(.semibold)).foregroundStyle(presentation.status.color) }
                if expanded {
                    if event.title != presentation.title { Text("Repère pédagogique : \(presentation.title)").font(.caption).foregroundStyle(BotaplataColors.textSecondary) }
                    if context == .global, let session { Text("Session \(session.id) · \(session.pair)").font(.caption) }
                    if let id = event.relatedOrderID { Text("Ordre · " + String(id.suffix(8))).font(.caption.monospaced()) }
                }
                Label(expanded ? "Masquer" : "Détails", systemImage: expanded ? "chevron.up" : "chevron.down").font(.caption).foregroundStyle(BotaplataColors.accent)
            }.foregroundStyle(BotaplataColors.textPrimary).padding(.vertical, 8).frame(minHeight: 44)
        }.buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(event.title). \(event.message). \(HistoryPresentation.fullDate(event.occurredAt))")
            .accessibilityHint(expanded ? "Masquer le détail" : "Afficher le détail")
    }
}

struct EventMetadataRow: View { let title: String; let value: String; var body: some View { HStack { Text(title).foregroundStyle(BotaplataColors.textMuted); Spacer(); Text(value).foregroundStyle(BotaplataColors.textSecondary).monospacedDigit() }.font(.caption) } }

struct OrdersHistoryView: View {
    let session: SessionDetail
    let store: RealSessionHistoryStore
    var body: some View {
        OrdersView(content: store.orders[session.id] ?? .idle, hasMore: store.ordersPagination[session.id]?.hasMore ?? false, loadNext: { await store.loadNextOrders(sessionID: session.id) })
            .task(id: session.id) { await store.refreshOrders(sessionID: session.id) }
            .refreshable { await store.refreshOrders(sessionID: session.id) }
    }
}

struct OrdersView: View {
    let content: LoadedContent<[SessionOrder]>
    var hasMore = false
    var loadNext: () async -> Void = {}
    @State private var filter: PremiumOrderFilter = .all
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                PremiumSectionHeader(title: "Ordres", subtitle: "Exécutions et statuts reçus du backend")
                PremiumSegmentedControl(title: "Ordres", options: PremiumOrderFilter.allCases, selection: $filter, label: { $0.title })
                switch content {
                case .idle, .loading, .refreshing(nil): PremiumLoadingSkeleton(); PremiumLoadingSkeleton()
                case .error(let message): PremiumErrorState(title: "Ordres indisponibles", message: message)
                case .offline(nil): PremiumEmptyState(title: "Ordres hors ligne", message: "Aucun ordre en cache.", systemImage: "wifi.slash")
                case .loaded(let orders), .loadedFromCache(let orders), .refreshing(let orders?), .offline(let orders?), .stale(let orders), .partial(let orders):
                    if case .offline = content { PremiumOfflineBanner() }
                    let visible = orders.filter { filter.includes($0) }
                    if visible.isEmpty { PremiumEmptyState(title: "Aucun ordre dans ce filtre", message: "Filtre appliqué aux ordres chargés. Les pages suivantes peuvent contenir d’autres ordres.") }
                    ForEach(visible) { OrderRow(order: $0) }
                }
                if hasMore { PremiumSecondaryButton(title: "Charger d’autres ordres") { Task { await loadNext() } } }
            }.padding(16).safeAreaPadding(.bottom, 16)
        }
    }
}

struct DecisionsHistoryView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { PagedHistoryList(title: "Décisions", content: store.decisions[session.id] ?? .idle, emptyTitle: "Aucune décision", emptyMessage: "Aucune décision n'est disponible pour cette session.", loadNext: { await store.loadNextDecisions(sessionID: session.id) }, row: { DecisionRow(decision: $0) }).task { await store.refreshDecisions(sessionID: session.id) }.refreshable { await store.refreshDecisions(sessionID: session.id) } } }
struct SessionJournalHistoryView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { JournalView(session: SessionSummary(id: session.id, pair: session.pair, provider: session.provider, providerLabel: session.providerLabel, backendStatus: session.backendStatus, lifecycle: session.lifecycle, runtimeHealth: session.runtimeHealth, freshness: session.freshness, executionMode: session.executionMode), sessions: [], content: store.timelines[session.id] ?? .idle, warnings: store.warnings[session.id] ?? [], context: .session, loadNext: { await store.loadNextTimeline(sessionID: session.id) }, refresh: { await store.refreshTimeline(sessionID: session.id) }, hasMore: store.timelinePagination[session.id]?.hasMore ?? false).task { await store.refreshTimeline(sessionID: session.id) } } }

struct PagedHistoryList<Item: Identifiable & Sendable, Row: View>: View { let title: String; let content: LoadedContent<[Item]>; let emptyTitle: String; let emptyMessage: String; let loadNext: () async -> Void; let row: (Item) -> Row; var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text(title).font(BotaplataTypography.sectionTitle).accessibilityAddTraits(.isHeader); switch content { case .idle, .loading: ForEach(0..<3, id: \.self) { _ in PremiumSkeletonCard() }; case .error: PremiumErrorState(title: "Chargement impossible", message: "Vérifiez votre connexion puis réessayez."); case .loaded(let items), .loadedFromCache(let items), .refreshing(let items?), .offline(let items?), .partial(let items), .stale(let items): if items.isEmpty { PremiumEmptyState(title: emptyTitle, message: emptyMessage) } else { ForEach(items) { item in row(item).task { if item.id == items.last?.id { await loadNext() } } }; if case .refreshing = content { ProgressView().frame(maxWidth: .infinity) } }; case .refreshing(nil), .offline(nil): PremiumErrorState(title: "Chargement impossible", message: "Vérifiez votre connexion puis réessayez.") } }.padding().safeAreaPadding(.bottom, BotaplataSpacing.xl) } } }
struct OrderRow: View {
    let order: SessionOrder
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: order.side == .buy ? "arrow.down.left" : order.side == .sell ? "arrow.up.right" : "questionmark").font(.headline).foregroundStyle(order.side == .unknown ? BotaplataColors.textSecondary : BotaplataColors.accent).frame(width: 40, height: 40).background(BotaplataColors.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) { Text(order.side.label).font(.headline); Text(order.symbol).font(.caption).foregroundStyle(BotaplataColors.textSecondary) }
                    Spacer()
                    Text(order.provider.displayName).font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                }
                StatusPill(status: order.status.premiumBadge,
                           text: order.status == .open ? "Ouvert · état local" : order.statusLabel ?? order.status.label)
                Text((order.filledAt ?? order.updatedAt ?? order.createdAt).map(HistoryPresentation.fullDate) ?? "Horodatage non fourni")
                    .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                row("Quantité exécutée", order.executedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible")
                row("Prix moyen exécuté", FinancialFormatters.money(order.averageFillPrice))
                row("Montant exécuté", FinancialFormatters.money(order.executedQuoteAmount))
                row("Frais constatés", FinancialFormatters.money(order.feesQuote))
                PremiumKeyValueRow(label: "P&L net réalisé", value: FinancialFormatters.money(order.realizedPnLNetQuote), valueColor: PremiumValueTone.pnl(order.realizedPnLNetQuote).color, monospaced: true)
                DisclosureGroup("Détails de l’ordre") {
                    row("Type", order.orderType?.uppercased() ?? "Indisponible")
                    row("Quantité demandée", order.requestedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible")
                    row("Prix limite", FinancialFormatters.money(order.limitPrice))
                    row("Réconciliation", order.reconciliationState ?? "Non fournie")
                    Text("Statut reçu du backend ; un état local ouvert ne certifie pas que l’ordre est encore ouvert chez Kraken.").font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                }
            }
        }
    }
    private func row(_ label: String, _ value: String) -> some View { PremiumKeyValueRow(label: label, value: value, monospaced: true) }
}
struct DecisionRow: View { let decision: SessionDecision; var body: some View { BotaplataCard { VStack(alignment: .leading, spacing: 8) { Text(HistoryPresentation.fullDate(decision.createdAt)).font(.caption).foregroundStyle(BotaplataColors.textSecondary); Text(decision.summaryTitle).font(.headline); Text(decision.summaryMessage).foregroundStyle(BotaplataColors.textSecondary); if let price = decision.price { Text("Prix : \(FinancialFormatters.money(price))").monospacedDigit() }; DisclosureGroup("Voir le détail de l'analyse") { DetailList(title: "Conditions favorables", items: decision.buyConditions); DetailList(title: "Points à vérifier", items: decision.sellConditions + (decision.advice.map { [$0] } ?? [])); DetailList(title: "Éléments bloquants", items: decision.blockers); if let s = decision.score { Text("Score technique : \(FinancialFormatters.decimal(s, min: 0, max: 4))").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } } } }
struct DetailList: View { let title: String; let items: [String]; var body: some View { if !items.isEmpty { Text(title).font(.subheadline.weight(.semibold)); ForEach(items, id: \.self) { Text("• \($0)").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } }

struct SessionChartView: View { let session: SessionDetail; let store: RealSessionHistoryStore; var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { switch store.charts[session.id] ?? .idle { case .idle, .loading: PremiumSkeletonCard(); case .loaded(let c), .loadedFromCache(let c), .refreshing(let c?), .offline(let c?), .stale(let c): SessionHistoryChartContent(chart: c); case .error: PremiumErrorState(title: "Graphique indisponible", message: "Vérifiez votre connexion puis réessayez."); default: PremiumErrorState(title: "Graphique indisponible", message: "Vérifiez votre connexion puis réessayez.") } }.padding() }.task { await store.refreshChart(sessionID: session.id) }.refreshable { await store.refreshChart(sessionID: session.id) } } }
struct SessionHistoryChartContent: View {
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
#Preview("Graphique sans points") { NavigationStack { SessionHistoryChartContent(chart: PreviewFixtures.sessionChart) } }
#Preview("Ordres") { NavigationStack { PagedHistoryList(title: "Ordres", content: .loaded(PreviewFixtures.sessionOrders), emptyTitle: "Aucun ordre", emptyMessage: "", loadNext: {}, row: { OrderRow(order: $0) }) } }
#Preview("Transactions") { NavigationStack { PagedHistoryList(title: "Transactions", content: .loaded(PreviewFixtures.sessionOrders), emptyTitle: "Aucun ordre", emptyMessage: "", loadNext: {}, row: { OrderRow(order: $0) }) } }
#Preview("Décisions historiques") { NavigationStack { PagedHistoryList(title: "Décisions", content: .loaded(PreviewFixtures.sessionDecisions), emptyTitle: "Aucune décision", emptyMessage: "", loadNext: {}, row: { DecisionRow(decision: $0) }) } }
#Preview("Graphique sans série") { NavigationStack { SessionHistoryChartContent(chart: PreviewFixtures.sessionChart) } }

private extension OrderStatus {
    var premiumBadge: BadgeStatus {
        switch self {
        case .filled: .success
        case .rejected, .reconciliationBlocked, .reconciliationFailed: .danger
        case .partiallyFilled, .reconciliationRequired: .warning
        case .submissionStarted, .submitted, .open: .waiting
        case .canceled, .unknown: .neutral
        }
    }
}
