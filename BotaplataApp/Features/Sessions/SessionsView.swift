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
            case let .detail(id, section):
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

enum SessionListFilter: String, CaseIterable, Identifiable {
    case all, active, history, watch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Toutes"
        case .active: "En cours"
        case .history: "Historique"
        case .watch: "À surveiller"
        }
    }
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
        session.runtimeHealth == .degraded ||
            session.runtimeHealth == .unavailable ||
            session.freshness.status == .stale ||
            session.lifecycle == .reconciliationPending ||
            session.backendStatus == "safety_blocked" ||
            session.backendStatus == "error"
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
        [session.pair, session.provider.displayName, session.providerLabel, session.strategyName, session.backendStatus]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
    }

    static func shouldShowPosition(_ position: OpenPosition?) -> Bool { (position?.quantity ?? 0) > 0 }

    static func activeOrderStatusText(_ status: OrderStatus) -> String {
        switch status {
        case .submissionStarted: "Préparation de l’ordre"
        case .submitted: "Envoyé à Kraken"
        case .open: "En attente sur Kraken"
        case .partiallyFilled: "Partiellement exécuté"
        case .filled: "Confirmé par Kraken"
        case .reconciliationRequired: "Vérification en cours"
        case .reconciliationBlocked: "Vérification bloquée"
        case .reconciliationFailed: "Vérification échouée"
        case .rejected: "Refusé"
        case .canceled: "Annulé"
        case .unknown: "Préparation"
        }
    }

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

    private static func moneyIfPresent(_ amount: MoneyAmount?) -> String? {
        amount?.value == nil ? nil : FinancialFormatters.money(amount)
    }
}

struct SessionsView: View {
    let content: LoadedContent<[SessionSummary]>
    var warnings: [Warning] = []
    var loadNext: (String?) async -> Void = { _ in }
    var refresh: () async -> Void = {}
    var historyStore: RealSessionHistoryStore? = nil

    @State private var selectedFilter: SessionListFilter = .all
    @State private var searchText = ""

    private var isOffline: Bool {
        if case .offline = content { return true }
        return false
    }

    private var visibleItems: [SessionSummary]? {
        switch content {
        case let .loaded(items), let .loadedFromCache(items), let .refreshing(.some(items)), let .offline(.some(items)), let .partial(items), let .stale(items):
            return items
        case .idle, .loading, .error, .refreshing(nil), .offline(nil):
            return nil
        }
    }

    private var filteredItems: [SessionSummary] {
        SessionsPresentation.filtered(visibleItems ?? [], filter: selectedFilter, query: searchText)
    }

    private var activeItems: [SessionSummary] { filteredItems.filter { !$0.isHistorical } }
    private var historicalItems: [SessionSummary] { filteredItems.filter(\.isHistorical) }

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                    header
                    banners
                    contentView
                }
                .padding()
                .safeAreaPadding(.bottom, BotaplataSpacing.xl)
            }
        }
        .navigationTitle("Sessions")
        .searchable(text: $searchText, prompt: "Paire, provider, stratégie")
        .refreshable { await refresh() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            Text("Sessions")
                .font(BotaplataTypography.largeTitle)
                .foregroundStyle(BotaplataColors.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(SessionListFilter.allCases) { filter in
                        Button { selectedFilter = filter } label: {
                            FilterPill(title: filter.title, isSelected: selectedFilter == filter)
                        }
                        .accessibilityLabel("Filtre \(filter.title)")
                        .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                    }
                }
            }
        }
    }

    @ViewBuilder private var banners: some View {
        if isOffline { PremiumOfflineBanner() }
        ForEach(warnings) { WarningBanner(warning: $0) }
    }

    @ViewBuilder private var contentView: some View {
        switch content {
        case .idle, .loading:
            loadingView
        case .error:
            PremiumErrorState(title: "Impossible de charger les sessions", message: "Vérifiez votre connexion puis réessayez.")
        case .loaded, .loadedFromCache, .refreshing(.some), .offline(.some), .partial, .stale:
            loadedView
        case .refreshing(nil), .offline(nil):
            PremiumErrorState(title: "Impossible de charger les sessions", message: "Vérifiez votre connexion puis réessayez.")
        }
    }

    private var loadingView: some View {
        ForEach(0..<3, id: \.self) { _ in PremiumSkeletonCard() }
    }

    @ViewBuilder private var loadedView: some View {
        if filteredItems.isEmpty {
            PremiumEmptyState(title: "Aucune session réelle", message: "Les sessions Kraken disponibles apparaîtront ici.")
        } else {
            sessionSections
        }
    }

    @ViewBuilder private var sessionSections: some View {
        if !activeItems.isEmpty {
            SectionHeader(title: "Sessions en cours", subtitle: nil)
            rows(activeItems)
        }
        if !historicalItems.isEmpty {
            SectionHeader(title: "Historique", subtitle: nil)
            rows(historicalItems)
        }
    }

    private func rows(_ items: [SessionSummary]) -> some View {
        ForEach(items) { session in
            NavigationLink(value: SessionRoute.detail(id: session.id, section: .overview)) {
                PremiumSessionCard(session: session)
                    .task { await loadNext(session.id) }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(accessibilityLabel(for: session))
        }
    }

    private func accessibilityLabel(for session: SessionSummary) -> String {
        let pair = session.pair.replacingOccurrences(of: "/", with: " ")
        let pnl = SessionsPresentation.pnlLine(session).map { line in
            "\(line.label) \(FinancialFormatters.money(line.value))"
        } ?? "résultat indisponible"
        let freshness = SessionFreshnessPresentation.text(for: session.freshness)
        return "\(pair), \(SessionsPresentation.statusText(session)), \(SessionsPresentation.lifecycleTitle(session.lifecycle)), \(pnl), \(freshness)."
    }
}

struct PremiumSessionCard: View {
    let session: SessionSummary

    private var subtitle: String {
        [session.strategyName, session.providerLabel ?? session.provider.displayName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var formattedPnL: String {
        guard let line = SessionsPresentation.pnlLine(session) else { return "Indisponible" }
        return line.value == nil ? "Indisponible" : FinancialFormatters.money(line.value)
    }

    private var pnlLabel: String? { SessionsPresentation.pnlLine(session)?.label }
    private var freshnessText: String { SessionFreshnessPresentation.text(for: session.freshness) }

    var body: some View {
        PremiumCard(variant: SessionsPresentation.shouldWatch(session) ? .warning : .normal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.pair).font(BotaplataTypography.cardTitle)
                        Text(subtitle).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: SessionsPresentation.status(session), text: SessionsPresentation.statusText(session))
                }
                Text(SessionsPresentation.lifecycleTitle(session.lifecycle)).font(.headline)
                Text(session.lifecycle.userMessage).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary).lineLimit(2)
                HStack {
                    if let pnlLabel {
                        VStack(alignment: .leading) {
                            Text(pnlLabel).font(.caption).foregroundStyle(BotaplataColors.textMuted)
                            Text(formattedPnL).font(BotaplataTypography.monoValue).foregroundStyle(BotaplataColors.textPrimary).monospacedDigit()
                        }
                    }
                    Spacer()
                    FreshnessBadge(freshness: session.freshness)
                }
                Text(freshnessText).font(.caption).foregroundStyle(BotaplataColors.textMuted)
            }
        }
    }
}

struct SessionDetailContainerView: View {
    let sessionID: String
    let initialSection: NotificationNavigationTarget.Section
    let content: LoadedContent<SessionDetail>
    let load: () async -> Void
    let historyStore: RealSessionHistoryStore?

    @State private var selectedSection: NotificationNavigationTarget.Section

    init(sessionID: String, initialSection: NotificationNavigationTarget.Section, content: LoadedContent<SessionDetail>, load: @escaping () async -> Void, historyStore: RealSessionHistoryStore?) {
        self.sessionID = sessionID
        self.initialSection = initialSection
        self.content = content
        self.load = load
        self.historyStore = historyStore
        _selectedSection = State(initialValue: initialSection)
    }

    private var isOffline: Bool {
        if case .offline = content { return true }
        return false
    }

    var body: some View {
        ZStack {
            PremiumBackground()
            detailContent
        }
        .navigationTitle("Détail")
        .task(id: sessionID) { await load() }
    }

    @ViewBuilder private var detailContent: some View {
        switch content {
        case let .loaded(session), let .refreshing(.some(session)), let .offline(.some(session)), let .stale(session), let .loadedFromCache(session):
            SessionDetailContent(session: session, selectedSection: $selectedSection, compact: false, historyStore: historyStore, isOffline: isOffline)
        case .error:
            PremiumErrorState(title: "Impossible de charger la session", message: "Vérifiez la connexion au serveur Botaplata.").padding()
        case .idle, .loading, .refreshing(nil), .offline(nil), .partial:
            VStack(spacing: BotaplataSpacing.md) { PremiumSkeletonCard(); PremiumSkeletonCard(); PremiumSkeletonCard() }.padding()
        }
    }
}

struct SessionDetailView: View {
    let session: SessionDetail
    @State private var selectedSection: NotificationNavigationTarget.Section = .overview

    var body: some View {
        ZStack {
            PremiumBackground()
            SessionDetailContent(session: session, selectedSection: $selectedSection, compact: false, historyStore: nil, isOffline: false)
        }
        .navigationTitle(session.pair)
    }
}

struct SessionDetailContent: View {
    let session: SessionDetail
    @Binding var selectedSection: NotificationNavigationTarget.Section
    let compact: Bool
    let historyStore: RealSessionHistoryStore?
    let isOffline: Bool
    @Environment(RealStrategyExplanationStore.self) private var strategyExplanationStore

    private var headerSubtitle: String {
        [session.providerLabel ?? session.provider.displayName, session.strategyName]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var liveStatusText: String { session.lifecycle == .stopped ? "Terminée" : "LIVE" }
    private var liveStatus: BadgeStatus { session.lifecycle == .stopped ? .neutral : .active }
    private var freshnessText: String { SessionFreshnessPresentation.text(for: session.freshness) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                detailHeader
                sectionSelector
            }
            .padding([.horizontal, .top])
            sectionContent
        }
        .safeAreaPadding(.bottom, BotaplataSpacing.xl)
    }

    private var detailHeader: some View {
        PremiumCard(variant: .hero) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.pair).font(BotaplataTypography.largeTitle)
                        Text(headerSubtitle).foregroundStyle(BotaplataColors.textSecondary)
                    }
                    Spacer()
                    StatusPill(status: liveStatus, text: liveStatusText)
                }
                HStack {
                    StatusPill(status: .waiting, text: SessionsPresentation.lifecycleTitle(session.lifecycle))
                    FreshnessBadge(freshness: session.freshness)
                }
                Text(session.lifecycle.userMessage).foregroundStyle(BotaplataColors.textSecondary)
                Text(freshnessText).font(.caption).foregroundStyle(BotaplataColors.textMuted)
            }
        }
    }

    private var sectionSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(NotificationNavigationTarget.Section.allCases, id: \.self) { section in
                    Button { selectedSection = section } label: {
                        FilterPill(title: section.title, isSelected: selectedSection == section)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Section \(section.title)" + (selectedSection == section ? ", sélectionnée" : ""))
                }
            }
        }
    }

    @ViewBuilder private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            overview
        case .analysis:
            analysis
        case .journal:
            journal
        case .orders:
            orders
        case .decisions:
            decisions
        case .chart:
            chart
        }
    }

    private var overview: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                if isOffline { PremiumOfflineBanner() }
                ForEach(session.warnings) { WarningBanner(warning: $0) }
                ReconciliationCard(session: session)
                stateCard
                marketCard
                DecisionSummaryCard(session: session, detailed: true)
                StrategyConditionsCard(decision: session.decision)
                PositionCard(session: session)
                if let order = session.activeOrder { ActiveOrderCard(order: order) }
                SessionFinancialSummaryCard(session: session)
                FeeAwareCard(fee: session.feeAware)
                HealthFreshnessCard(session: session, cached: isOffline)
            }
            .padding()
        }
    }

    @ViewBuilder private var analysis: some View {
        StrategyExplanationSectionView(session: session, store: strategyExplanationStore)
    }

    @ViewBuilder private var journal: some View {
        if let historyStore { SessionJournalHistoryView(session: session, store: historyStore) }
        else { PremiumEmptyState(title: "Journal indisponible", message: "Aucune source locale n'est attachée à cette preview.") }
    }

    @ViewBuilder private var orders: some View {
        if let historyStore { OrdersHistoryView(session: session, store: historyStore) }
        else { PremiumEmptyState(title: "Ordres indisponibles", message: "Aucune source locale n'est attachée à cette preview.") }
    }

    @ViewBuilder private var decisions: some View {
        if let historyStore { DecisionsHistoryView(session: session, store: historyStore) }
        else { PremiumEmptyState(title: "Décisions indisponibles", message: "Aucune source locale n'est attachée à cette preview.") }
    }

    @ViewBuilder private var chart: some View {
        RealTradingChartSection(session: session)
    }

    private var stateCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("État actuel").font(BotaplataTypography.cardTitle)
                Text(SessionsPresentation.lifecycleTitle(session.lifecycle)).font(.headline)
                Text(session.lifecycle.userMessage).foregroundStyle(BotaplataColors.textSecondary)
                StatusPill(status: session.runtimeHealth == .healthy ? .success : .warning, text: session.runtimeHealth.label)
                FreshnessBadge(freshness: session.freshness)
                if let errors = session.monitoringConsecutiveErrors, errors > 0 {
                    Text("\(errors) erreurs consécutives").foregroundStyle(BotaplataColors.warning)
                }
            }
        }
    }

    private var marketCard: some View {
        PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Marché").font(BotaplataTypography.cardTitle); row("Prix actuel", FinancialFormatters.money(session.currentPrice)) } }
    }

    private func row(_ key: String, _ value: String) -> some View {
        PremiumKeyValueRow(label: key, value: value, monospaced: true)
    }
}

extension NotificationNavigationTarget.Section {
    var title: String {
        switch self {
        case .overview: "Aperçu"
        case .analysis: "Analyse"
        case .journal: "Journal"
        case .orders: "Ordres"
        case .decisions: "Décisions"
        case .chart: "Graphique"
        }
    }
}

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
#Preview("Graphique sans série") { NavigationStack { SessionHistoryChartContent(chart: PreviewFixtures.sessionChart) } }
#Preview("Session overview waiting buy") { NavigationStack { SessionDetailView(session: PreviewFixtures.waitingBuyWithConditions) } }
#Preview("Session overview position ouverte") { NavigationStack { SessionDetailView(session: PreviewFixtures.krakenDetail) } }
#Preview("Session overview ordre pending") { NavigationStack { SessionDetailView(session: PreviewFixtures.waitingBuyFill) } }
#Preview("Session overview fee-aware") { NavigationStack { SessionDetailView(session: PreviewFixtures.krakenDetail) } }
#Preview("Session conditions avec blockers") { StrategyConditionsCard(decision: PreviewFixtures.waitingBuyWithConditions.decision).padding().background(BotaplataColors.background) }
#Preview("Session conditions sans valeurs numériques") { StrategyConditionsCard(decision: PreviewFixtures.waitingBuyWithConditions.decision).padding().background(BotaplataColors.background) }

struct StrategyExplanationSectionView: View {
    let session: SessionDetail
    @Bindable var store: RealStrategyExplanationStore
    var body: some View { ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { content }.padding() }.task { await store.load(sessionID: session.id, reason: "sectionOpened") }.refreshable { await store.refresh(sessionID: session.id) }.onDisappear { store.cancel(sessionID: session.id) } }
    @ViewBuilder private var content: some View { switch store.state { case .idle, .loading: PremiumSkeletonCard(); PremiumSkeletonCard(); case .error(let message): PremiumErrorState(title: "Impossible de charger l’analyse", message: message); PremiumSecondaryButton(title: "Réessayer") { Task { await store.refresh(sessionID: session.id) } }; case .offlineCached: if let e = store.explanation { PremiumCard(variant: .warning) { Text("Dernière analyse connue").font(BotaplataTypography.cardTitle); Text(store.lastUpdatedAt.map(HistoryPresentation.fullDate) ?? "Date inconnue").foregroundStyle(BotaplataColors.textSecondary) }; StrategyExplanationContent(explanation: e) }; case .loaded, .refreshing, .empty: if store.isRefreshing { PremiumLoadingState(title: "Actualisation", message: "Botaplata récupère la dernière décision.") }; if let e = store.explanation { StrategyExplanationContent(explanation: e) } else { PremiumEmptyState(title: "Analyse indisponible", message: "Les indicateurs ne sont pas encore disponibles.") } } }
}

struct StrategyExplanationContent: View { let explanation: StrategyExplanation
    var body: some View { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { StrategyDecisionHeroCard(explanation: explanation); StrategyScoreCard(score: explanation.score); StrategyConditionsExplanationCard(conditions: explanation.conditions); if !explanation.blockers.isEmpty { StrategyBlockersCard(blockers: explanation.blockers) }; StrategyMarketCard(market: explanation.market); StrategyIndicatorsCard(indicators: explanation.indicators.indicators); StrategyAnalysisBaseCard(analysis: explanation.analysis); if let p = explanation.positionProtection { StrategyPositionProtectionCard(protection: p) }; StrategyTechnicalDetailsCard(explanation: explanation) } }
}

struct StrategyDecisionHeroCard: View { let explanation: StrategyExplanation; var body: some View { PremiumCard(variant: explanation.analysis.freshness.isStale || explanation.decision.code == .safetyBlocked ? .warning : .hero) { VStack(alignment: .leading, spacing: 10) { Label(explanation.decision.label, systemImage: icon).font(BotaplataTypography.cardTitle); Text(explanation.decision.summary).foregroundStyle(BotaplataColors.textSecondary); if let score = explanation.score { Text("\(score.currentRaw ?? "—") / \(score.requiredRaw ?? "—")").font(.title2.bold()).monospacedDigit() }; if let close = explanation.analysis.candleCloseTime { Text("Dernière analyse : bougie clôturée à \(HistoryPresentation.time(close))").font(.caption).foregroundStyle(BotaplataColors.textMuted) } } } }
    private var icon: String { switch explanation.decision.code { case .wait, .watch: "clock"; case .buyReady, .buySubmitted, .buyConfirmed: "arrow.up.circle"; case .positionOpen: "shield.checkered"; case .safetyBlocked, .dataStale: "exclamationmark.shield"; case .historyPreparing: "hourglass"; default: "info.circle" } }
}
struct StrategyScoreCard: View { let score: StrategyScore?; var body: some View { PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Score et seuil").font(BotaplataTypography.cardTitle); if let score { Text(score.summary ?? "\(score.favorableConditions ?? 0) conditions sur \(score.totalConditions ?? 0) sont favorables").foregroundStyle(BotaplataColors.textSecondary); HStack { ForEach(0..<(score.totalConditions ?? 4), id: \.self) { i in Capsule().fill(i < (score.favorableConditions ?? 0) ? BotaplataColors.success : BotaplataColors.cardBorder).frame(height: 8) } }; PremiumKeyValueRow(label: "Score", value: "\(score.currentRaw ?? "—") / \(score.requiredRaw ?? "—")", monospaced: true); PremiumKeyValueRow(label: "Maximum", value: score.maximumRaw ?? "—", monospaced: true) } else { Text("Score en préparation").foregroundStyle(BotaplataColors.textSecondary) } } } } }
struct StrategyConditionsExplanationCard: View { let conditions: [StrategyCondition]; var body: some View { PremiumCard { VStack(alignment: .leading, spacing: 10) { Text("Conditions").font(BotaplataTypography.cardTitle); ForEach(conditions) { c in VStack(alignment: .leading, spacing: 5) { HStack { Text(c.label).font(.headline); Spacer(); StatusPill(status: c.status == .favorable ? .success : c.status == .blocked ? .danger : .waiting, text: statusText(c.status)) }; Text(c.summary).foregroundStyle(BotaplataColors.textSecondary); if let v = c.valueRaw { PremiumKeyValueRow(label: "Valeur", value: v, monospaced: true) }; if let t = c.thresholdRaw { PremiumKeyValueRow(label: "Seuil", value: t, monospaced: true) }; if let d = c.technicalDetail { DisclosureGroup("Détail technique") { Text(d).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } }.padding(.vertical, 4) } } } }; func statusText(_ s: StrategyConditionStatus) -> String { switch s { case .favorable: "Validé"; case .unfavorable: "À confirmer"; case .neutral: "Neutre"; case .unavailable: "Indisponible"; case .blocked: "Bloqué"; case .unknown: "À confirmer" } } }
struct StrategyBlockersCard: View { let blockers: [StrategyBlocker]; var body: some View { PremiumCard(variant: .warning) { VStack(alignment: .leading, spacing: 10) { Text("Ce qui bloque l’action").font(BotaplataTypography.cardTitle); ForEach(blockers) { b in VStack(alignment: .leading, spacing: 5) { Text(b.label).font(.headline); Text(b.summary).foregroundStyle(BotaplataColors.textSecondary); PremiumKeyValueRow(label: "Sévérité", value: b.severityRaw); if let r = b.recoverable { PremiumKeyValueRow(label: "Récupérable", value: r ? "Oui" : "Non") }; if let d = b.technicalDetail { DisclosureGroup("Détail technique") { Text(d).font(.caption) } } } } } } } }
struct StrategyMarketCard: View { let market: StrategyMarketContext; var body: some View { PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Contexte du marché").font(BotaplataTypography.cardTitle); PremiumKeyValueRow(label: "Régime", value: market.regime.label); PremiumKeyValueRow(label: "Momentum", value: market.momentum.label); if let s = market.summary { Text(s).foregroundStyle(BotaplataColors.textSecondary) }; market.regime.summary.map { Text($0).font(.caption).foregroundStyle(BotaplataColors.textMuted) }; market.momentum.summary.map { Text($0).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } } } }
struct StrategyIndicatorsCard: View { let indicators: [StrategyIndicator]; var body: some View { if !indicators.isEmpty { PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Indicateurs utilisés").font(BotaplataTypography.cardTitle); ForEach(indicators) { i in VStack(alignment: .leading, spacing: 4) { PremiumKeyValueRow(label: i.name, value: i.valueRaw ?? "Indisponible", monospaced: true); Text(i.help).font(.caption).foregroundStyle(BotaplataColors.textSecondary); if let d = i.technicalDetail { DisclosureGroup("Détail technique") { Text(d).font(.caption) } } } } } } } } }
struct StrategyAnalysisBaseCard: View { let analysis: StrategyAnalysisContext; var body: some View { PremiumCard(variant: analysis.freshness.isStale ? .warning : .normal) { VStack(alignment: .leading, spacing: 8) { Text("Base de l’analyse").font(BotaplataTypography.cardTitle); if analysis.freshness.isStale { Text("Les dernières données ne sont plus assez récentes.").foregroundStyle(BotaplataColors.warning) }; analysis.timeframe.map { PremiumKeyValueRow(label: "Timeframe", value: $0) }; analysis.candleCloseTime.map { PremiumKeyValueRow(label: "Bougie clôturée", value: HistoryPresentation.fullDate($0), monospaced: true) }; analysis.calculatedAt.map { PremiumKeyValueRow(label: "Calculé à", value: HistoryPresentation.fullDate($0), monospaced: true) }; analysis.nextRecalculationAt.map { PremiumKeyValueRow(label: "Prochain recalcul", value: HistoryPresentation.fullDate($0), monospaced: true) }; PremiumKeyValueRow(label: "Fraîcheur", value: analysis.freshness.label ?? analysis.freshness.status) } } } }
struct StrategyPositionProtectionCard: View { let protection: StrategyPositionProtection; var body: some View { PremiumCard(variant: .success) { VStack(alignment: .leading, spacing: 8) { Text("Protection de la position").font(BotaplataTypography.cardTitle); Text(protection.summary).foregroundStyle(BotaplataColors.textSecondary); [ ("Prix d’entrée", protection.entryPriceRaw), ("Prix actuel", protection.currentPriceRaw), ("PnL latent", protection.unrealizedPnLRaw), ("Seuil de rentabilité", protection.breakEvenPriceRaw), ("Prix minimum rentable", protection.minimumProfitablePriceRaw), ("Trailing stop", protection.trailingStopRaw) ].forEach { if let v = $0.1 { PremiumKeyValueRow(label: $0.0, value: v, monospaced: true) } }; if let t = protection.trailingActive { PremiumKeyValueRow(label: "Trailing actif", value: t ? "Oui" : "Non") }; if !protection.sellConditions.isEmpty { Text("Conditions de vente").font(.headline); ForEach(protection.sellConditions, id: \.self) { Text($0).font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } } } }
struct StrategyTechnicalDetailsCard: View { let explanation: StrategyExplanation; var body: some View { PremiumCard { DisclosureGroup("Détails techniques") { VStack(alignment: .leading, spacing: 6) { Text("Stratégie : \(explanation.strategy.code)"); if let d = explanation.decision.technicalDetail { Text(d) }; if let d = explanation.analysis.technicalDetail { Text(d) }; Text("Les valeurs sont fournies par le serveur Botaplata. L’iPhone ne recalcule aucun score, indicateur ou garde-fou.").foregroundStyle(BotaplataColors.textSecondary) }.font(.caption) } } } }
