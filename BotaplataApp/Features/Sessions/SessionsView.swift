import SwiftUI

struct SessionsContainerView: View {
    @State var store: RealSessionsStore
    @Environment(RealSessionHistoryStore.self) private var historyStore

    var body: some View {
        SessionsView(
            content: store.content,
            warnings: store.warnings,
            loadNext: { id in await store.loadNextPageIfNeeded(currentItemID: id) },
            refresh: { await store.refresh() },
            historyStore: historyStore
        )
        .task { store.start() }
        .navigationDestination(for: SessionRoute.self) { route in
            switch route {
            case .detail(let id, let section):
                SessionDetailContainerView(
                    sessionID: id,
                    initialSection: section,
                    content: store.details[id] ?? .idle,
                    load: { await store.loadDetail(id: id) },
                    historyStore: historyStore
                )
            }
        }
    }
}

enum SessionListFilter: String, CaseIterable, Identifiable { case all, active, history, watch
    var id: String { rawValue }
    var title: String { switch self { case .all: "Toutes"; case .active: "En cours"; case .history: "Historique"; case .watch: "À surveiller" } }
}

enum SessionsPresentation {
    static func filtered(_ items: [SessionSummary], filter: SessionListFilter, query: String) -> [SessionSummary] {
        let base = items.filter { session in
            switch filter {
            case .all: true
            case .active: !session.isHistorical
            case .history: session.isHistorical
            case .watch: shouldWatch(session)
            }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { searchableText($0).contains(q) }
    }

    static func shouldWatch(_ session: SessionSummary) -> Bool {
        session.runtimeHealth == .degraded || session.runtimeHealth == .unavailable || session.freshness.status == .stale || session.lifecycle == .reconciliationPending || session.backendStatus == "safety_blocked" || session.backendStatus == "error"
    }

    static func lifecycleTitle(_ lifecycle: SessionLifecycleState) -> String {
        switch lifecycle {
        case .waitingBuy: "Recherche une opportunité"
        case .preparingBuy: "Préparation"
        case .waitingBuyFill: "Achat en attente"
        case .positionOpen, .waitingSell, .monitoringPosition: "Position ouverte"
        case .waitingSellFill: "Vente en attente"
        case .reconciliationPending: "Vérification en cours"
        case .stopped: "Terminée"
        case .unknown: "État à confirmer"
        }
    }

    static func statusText(_ session: SessionSummary) -> String {
        if shouldWatch(session) { return "À surveiller" }
        return session.isHistorical ? "Terminée" : "LIVE"
    }

    static func status(_ session: SessionSummary) -> BadgeStatus {
        if shouldWatch(session) { return .warning }
        return session.isHistorical ? .neutral : .active
    }

    static func pnlLine(_ session: SessionSummary) -> (label: String, value: MoneyAmount?)? {
        if let pnl = session.unrealizedPnLQuote, pnl.value != nil { return ("Résultat latent", pnl) }
        if let pnl = session.realizedPnLNetQuote, pnl.value != nil { return ("Résultat réalisé", pnl) }
        return session.isHistorical ? ("Résultat réalisé", nil) : nil
    }

    static func searchableText(_ session: SessionSummary) -> String {
        [session.pair, session.provider.displayName, session.providerLabel, session.strategyName, session.backendStatus].compactMap { $0 }.joined(separator: " ").lowercased()
    }

    static func shouldShowPosition(_ position: OpenPosition?) -> Bool { (position?.quantity ?? 0) > 0 }
    static func activeOrderStatusText(_ status: OrderStatus) -> String { switch status { case .submitted: "Envoyé à Kraken"; case .open: "En attente sur Kraken"; case .partiallyFilled: "Partiellement exécuté"; case .filled: "Confirmé par Kraken"; case .reconciliationRequired: "Vérification en cours"; case .reconciliationBlocked: "Vérification bloquée"; case .reconciliationFailed: "Vérification échouée"; case .rejected: "Refusé"; case .canceled: "Annulé"; case .unknown: "Préparation" } }
    static func feeAwareRows(_ fee: FeeAwareSummary) -> [(String, String)] {
        [
            ("Prix de revient frais inclus", moneyIfPresent(fee.costBasisPrice)),
            ("Frais d'achat réels", moneyIfPresent(fee.buyFeeQuote)),
            ("Taux de frais effectif", fee.buyFeeRateEffective.map { FinancialFormatters.percent($0) }),
            ("Frais de vente estimés", moneyIfPresent(fee.estimatedSellFeeQuote)),
            ("Source estimation", fee.estimatedSellFeeSource),
            ("Seuil de rentabilité", moneyIfPresent(fee.breakEvenPrice)),
            ("Prix minimum rentable", moneyIfPresent(fee.minimumProfitableExitPrice)),
            ("Slippage estimé", fee.estimatedSlippageRate.map { FinancialFormatters.percent($0) }),
            ("Frais totaux estimés", moneyIfPresent(fee.totalEstimatedCycleFeesQuote))
        ].compactMap { label, value in value.map { (label, $0) } }
    }
    private static func moneyIfPresent(_ amount: MoneyAmount?) -> String? { amount?.value == nil ? nil : FinancialFormatters.money(amount) }
}

struct SessionsView: View {
    let content: LoadedContent<[SessionSummary]>; var warnings: [Warning] = []; var loadNext: (String?) async -> Void = { _ in }; var refresh: () async -> Void = {}; var historyStore: RealSessionHistoryStore? = nil
    @State private var selectedFilter: SessionListFilter = .all
    @State private var searchText = ""

    var body: some View {
        ZStack { PremiumBackground(); ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { header; banners; contentView }.padding().safeAreaPadding(.bottom, BotaplataSpacing.xl) } }
            .navigationTitle("Sessions")
            .searchable(text: $searchText, prompt: "Paire, provider, stratégie")
            .refreshable { await refresh() }
    }
    var header: some View { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Sessions").font(BotaplataTypography.largeTitle).foregroundStyle(BotaplataColors.textPrimary); ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(SessionListFilter.allCases) { filter in Button { selectedFilter = filter } label: { FilterPill(title: filter.title, isSelected: selectedFilter == filter) }.accessibilityLabel("Filtre \(filter.title)").accessibilityAddTraits(selectedFilter == filter ? .isSelected : []) } } } } }
    @ViewBuilder var banners: some View { if isOffline { PremiumOfflineBanner() }; ForEach(warnings) { WarningBanner(warning: $0) } }
    @ViewBuilder var contentView: some View { switch content { case .idle, .loading: ForEach(0..<3, id: \.self) { _ in PremiumSkeletonCard() }; case .error: PremiumErrorState(title: "Impossible de charger les sessions", message: "Vérifiez votre connexion puis réessayez."); case .loaded(let items), .loadedFromCache(let items), .refreshing(let items?), .offline(let items?), .partial(let items), .stale(let items): let filtered = SessionsPresentation.filtered(items, filter: selectedFilter, query: searchText); if filtered.isEmpty { PremiumEmptyState(title: "Aucune session réelle", message: "Les sessions Kraken disponibles apparaîtront ici.") } else { sessionSections(filtered) }; case .refreshing(nil), .offline(nil): PremiumErrorState(title: "Impossible de charger les sessions", message: "Vérifiez votre connexion puis réessayez.") } }
    var isOffline: Bool { if case .offline = content { true } else { false } }
    func sessionSections(_ items: [SessionSummary]) -> some View { Group { let active = items.filter { !$0.isHistorical }; let history = items.filter(\.isHistorical); if !active.isEmpty { SectionHeader(title: "Sessions en cours", subtitle: nil); rows(active) }; if !history.isEmpty { SectionHeader(title: "Historique", subtitle: nil); rows(history) } } }
    func rows(_ items: [SessionSummary]) -> some View { ForEach(items) { session in NavigationLink(value: SessionRoute.detail(id: session.id, section: .overview)) { PremiumSessionCard(session: session).task { await loadNext(session.id) } }.buttonStyle(.plain).accessibilityAddTraits(.isButton).accessibilityLabel(accessibility(for: session)) } }
    func accessibility(for s: SessionSummary) -> String { let pnl = SessionsPresentation.pnlLine(s).map { "\($0.label) \(FinancialFormatters.money($0.value))" } ?? "résultat indisponible"; return "\(s.pair.replacingOccurrences(of: "/", with: " ")), \(SessionsPresentation.statusText(s)), \(SessionsPresentation.lifecycleTitle(s.lifecycle)), \(pnl), \(freshnessText(s.freshness))." }
}

struct PremiumSessionCard: View { let session: SessionSummary
    var body: some View { PremiumCard(variant: SessionsPresentation.shouldWatch(session) ? .warning : .normal) { VStack(alignment: .leading, spacing: 12) { HStack(alignment: .top) { VStack(alignment: .leading, spacing: 4) { Text(session.pair).font(BotaplataTypography.cardTitle); Text([session.strategyName, session.providerLabel ?? session.provider.displayName].compactMap { $0 }.joined(separator: " · ")).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary) }; Spacer(); StatusPill(status: SessionsPresentation.status(session), text: SessionsPresentation.statusText(session)) }; Text(SessionsPresentation.lifecycleTitle(session.lifecycle)).font(.headline); Text(session.lifecycle.userMessage).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary).lineLimit(2); HStack { if let line = SessionsPresentation.pnlLine(session) { VStack(alignment: .leading) { Text(line.label).font(.caption).foregroundStyle(BotaplataColors.textMuted); Text(line.value == nil ? "Indisponible" : FinancialFormatters.money(line.value)).font(BotaplataTypography.monoValue).foregroundStyle(BotaplataColors.textPrimary).monospacedDigit() } }; Spacer(); FreshnessBadge(freshness: session.freshness) }; Text(freshnessText(session.freshness)).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } }
}

struct SessionDetailContainerView: View { let sessionID: String; let initialSection: NotificationNavigationTarget.Section; let content: LoadedContent<SessionDetail>; let load: () async -> Void; let historyStore: RealSessionHistoryStore?
    var body: some View { ZStack { PremiumBackground(); ScrollView { Group { switch content { case .loaded(let s), .refreshing(let s?), .offline(let s?), .stale(let s), .loadedFromCache(let s): SessionDetailContent(session: s, selectedSection: initialSection, compact: false, historyStore: historyStore, isOffline: isOffline); case .error: PremiumErrorState(title: "Session indisponible", message: "Vérifiez votre connexion puis réessayez."); default: PremiumSkeletonCard() } }.padding() } }.navigationTitle("Détail").task { await load() } }
    var isOffline: Bool { if case .offline = content { true } else { false } }
}
struct SessionDetailView: View { let session: SessionDetail; var body: some View { ZStack { PremiumBackground(); ScrollView { SessionDetailContent(session: session, selectedSection: .overview, compact: false, historyStore: nil, isOffline: false).padding() } }.navigationTitle(session.pair) } }
struct SessionDetailContent: View { let session: SessionDetail; let selectedSection: NotificationNavigationTarget.Section; let compact: Bool; let historyStore: RealSessionHistoryStore?; let isOffline: Bool
    var body: some View { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { detailHeader; sectionSelector; if isOffline { PremiumOfflineBanner() }; ForEach(session.warnings) { WarningBanner(warning: $0) }; if let reconciliation = session.reconciliation { WarningBanner(warning: reconciliation) }; sectionContent } }
    var detailHeader: some View { PremiumCard(variant: .hero) { VStack(alignment: .leading, spacing: 10) { HStack { VStack(alignment: .leading) { Text(session.pair).font(BotaplataTypography.largeTitle); Text([session.providerLabel ?? session.provider.displayName, session.strategyName].compactMap { $0 }.joined(separator: " · ")).foregroundStyle(BotaplataColors.textSecondary) }; Spacer(); StatusPill(status: session.lifecycle == .stopped ? .neutral : .active, text: session.lifecycle == .stopped ? "Terminée" : "LIVE") }; HStack { StatusPill(status: .waiting, text: SessionsPresentation.lifecycleTitle(session.lifecycle)); FreshnessBadge(freshness: session.freshness) }; Text(session.lifecycle.userMessage).foregroundStyle(BotaplataColors.textSecondary); Text(freshnessText(session.freshness)).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } }
    var sectionSelector: some View { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(NotificationNavigationTarget.Section.allCases, id: \.self) { section in NavigationLink(value: SessionRoute.detail(id: session.id, section: section)) { FilterPill(title: section.title, isSelected: selectedSection == section) }.buttonStyle(.plain).accessibilityLabel("Section \(section.title)") } } } }
    @ViewBuilder var sectionContent: some View { switch selectedSection { case .overview: overview; case .journal: if let historyStore { SessionJournalHistoryView(session: session, store: historyStore) } else { PremiumEmptyState(title: "Journal indisponible", message: "Aucune source locale n'est attachée à cette preview.") }; case .orders: if let historyStore { OrdersHistoryView(session: session, store: historyStore) } else { PremiumEmptyState(title: "Ordres indisponibles", message: "Aucune source locale n'est attachée à cette preview.") }; case .decisions: if let historyStore { DecisionsHistoryView(session: session, store: historyStore) } else { PremiumEmptyState(title: "Décisions indisponibles", message: "Aucune source locale n'est attachée à cette preview.") }; case .chart: if let historyStore { SessionChartView(session: session, store: historyStore) } else { ChartContent(chart: PreviewFixtures.sessionChart) } } }
    var overview: some View { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { stateCard; marketCard; positionCard; decisionCard; if let order = session.activeOrder { activeOrderCard(order) }; feeAwareCard; healthCard; pnlCard } }
    var stateCard: some View { PremiumCard { VStack(alignment:.leading, spacing: 10) { Text("État actuel").font(BotaplataTypography.cardTitle); Text(SessionsPresentation.lifecycleTitle(session.lifecycle)).font(.headline); Text(session.lifecycle.userMessage).foregroundStyle(BotaplataColors.textSecondary); StatusPill(status: session.runtimeHealth == .healthy ? .success : .warning, text: session.runtimeHealth.label); FreshnessBadge(freshness: session.freshness); if let errors = session.monitoringConsecutiveErrors, errors > 0 { Text("\(errors) erreurs consécutives").foregroundStyle(BotaplataColors.warning) } } } }
    var marketCard: some View { PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Marché").font(BotaplataTypography.cardTitle); row("Prix actuel", FinancialFormatters.money(session.currentPrice)) } } }
    var positionCard: some View { PremiumCard { VStack(alignment:.leading, spacing: 8) { Text("Position").font(BotaplataTypography.cardTitle); if SessionsPresentation.shouldShowPosition(session.position), let p = session.position { Text("Position ouverte").font(.headline); row("Quantité", p.quantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Prix moyen exécuté", FinancialFormatters.money(p.averageExecutionPrice)); row("Prix de revient frais inclus", FinancialFormatters.money(p.costBasisPrice)); row("Prix actuel", FinancialFormatters.money(session.currentPrice)); row("Résultat brut", FinancialFormatters.money(session.pnl?.gross)); row("Résultat net estimé", FinancialFormatters.money(session.pnl?.netEstimated)); Text("Le résultat net estimé tient compte des frais d'achat réels, des frais de vente estimés et du slippage estimé.").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } else { Text("Aucune position ouverte").font(.headline); Text("Botaplata cherche encore une opportunité.").foregroundStyle(BotaplataColors.textSecondary) } } } }
    var decisionCard: some View { PremiumCard { VStack(alignment:.leading, spacing: 8) { Text("Décision actuelle").font(BotaplataTypography.cardTitle); Text(session.decision.title).font(.headline); Text(session.decision.detail).foregroundStyle(BotaplataColors.textSecondary); if let f = session.decision.favorableConditions, let r = session.decision.requiredConditions { Text("\(f) conditions favorables sur \(r)").monospacedDigit() } } } }
    func activeOrderCard(_ order: TradingOrderSummary) -> some View { PremiumCard { VStack(alignment:.leading, spacing: 8) { Text("Ordre actif").font(BotaplataTypography.cardTitle); Text(order.side.uppercased()).font(.headline); StatusPill(status: order.status == .filled ? .success : order.status == .rejected ? .danger : .waiting, text: SessionsPresentation.activeOrderStatusText(order.status)); row("Quantité demandée", order.requestedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Quantité exécutée", order.executedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Prix limite", FinancialFormatters.money(order.limitPrice)); row("Prix moyen exécuté", FinancialFormatters.money(order.averageExecutionPrice)); Text(order.message).font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } }
    var feeAwareCard: some View { PremiumCard { VStack(alignment:.leading, spacing: 8) { Text("Frais / rentabilité").font(BotaplataTypography.cardTitle); ForEach(SessionsPresentation.feeAwareRows(session.feeAware), id: \.0) { row($0.0, $0.1) }; Text("Ces estimations proviennent du backend Botaplata.").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } }
    var healthCard: some View { PremiumCard { VStack(alignment:.leading, spacing: 8) { Text("Santé et fraîcheur").font(BotaplataTypography.cardTitle); row("Surveillance", session.runtimeHealth.label); row("Fraîcheur", freshnessText(session.freshness)); row("Mode", session.executionMode.rawValue) } } }
    var pnlCard: some View { PremiumCard { VStack(alignment:.leading, spacing: 8) { Text("Données financières").font(BotaplataTypography.cardTitle); row("Résultat latent", FinancialFormatters.money(session.pnl?.gross)); row("Résultat net estimé", FinancialFormatters.money(session.pnl?.netEstimated)); row("Résultat net réalisé", FinancialFormatters.money(session.pnl?.realizedNet)) } } }
    func row(_ k: String, _ v: String) -> some View { PremiumKeyValueRow(label: k, value: v, monospaced: true) }
}

extension NotificationNavigationTarget.Section { var title: String { switch self { case .overview: "Vue d’ensemble"; case .journal: "Journal"; case .orders: "Ordres"; case .decisions: "Décisions"; case .chart: "Graphique" } } }

func freshnessText(_ freshness: DataFreshness) -> String { guard let date = freshness.updatedAt else { return "Fraîcheur inconnue" }; let seconds = max(0, Int(Date().timeIntervalSince(date))); if freshness.status == .stale { return "Dernière donnée connue il y a \(relative(seconds))" }; return "Mis à jour il y a \(relative(seconds))" }
private func relative(_ seconds: Int) -> String { seconds < 60 ? "\(seconds) s" : seconds < 3600 ? "\(seconds / 60) min" : "\(seconds / 3600) h" }

#Preview("Liste nominale") { NavigationStack { SessionsView(content: .loaded(PreviewFixtures.sessionSummaries)) } }
#Preview("Liste filtrée en cours") { NavigationStack { SessionsView(content: .loaded(PreviewFixtures.sessionSummaries)) } }
#Preview("Liste historique") { NavigationStack { SessionsView(content: .loaded([PreviewFixtures.sessionSummaries[1]])) } }
#Preview("Liste à surveiller") { NavigationStack { SessionsView(content: .loaded([PreviewFixtures.watchSummary])) } }
#Preview("Liste vide") { NavigationStack { SessionsView(content: .loaded([])) } }
#Preview("Liste offline") { NavigationStack { SessionsView(content: .offline(PreviewFixtures.sessionSummaries)) } }
#Preview("Carte waiting_buy") { PremiumSessionCard(session: PreviewFixtures.waitingBuySummary).padding().background(BotaplataColors.background) }
#Preview("Carte position ouverte") { PremiumSessionCard(session: PreviewFixtures.sessionSummaries[0]).padding().background(BotaplataColors.background) }
#Preview("Carte reconciliation") { PremiumSessionCard(session: PreviewFixtures.reconciliationSummary).padding().background(BotaplataColors.background) }
#Preview("Détail overview") { NavigationStack { SessionDetailView(session: PreviewFixtures.krakenDetail) } }
#Preview("Détail sans position") { NavigationStack { SessionDetailView(session: PreviewFixtures.waitingBuy) } }
#Preview("Détail ordre BUY pending") { NavigationStack { SessionDetailView(session: PreviewFixtures.waitingBuyFill) } }
#Preview("Détail SELL pending") { NavigationStack { SessionDetailView(session: PreviewFixtures.sellPending) } }
#Preview("Détail fee-aware complet") { NavigationStack { SessionDetailView(session: PreviewFixtures.krakenDetail) } }
#Preview("Détail données anciennes") { NavigationStack { SessionDetailView(session: PreviewFixtures.staleDetail) } }
#Preview("Graphique sans série") { NavigationStack { ChartContent(chart: PreviewFixtures.sessionChart) } }
