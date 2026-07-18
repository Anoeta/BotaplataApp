import SwiftUI

struct DashboardView: View {
    let content: LoadedContent<RealActiveSnapshot>
    var unreadCount: Int = 0
    var openAlerts: () -> Void = {}
    var openSession: (String) -> Void = { _ in }
    var refresh: (() async -> Void)? = nil

    init(content: LoadedContent<RealActiveSnapshot>, unreadCount: Int = 0, openAlerts: @escaping () -> Void = {}, openSession: @escaping (String) -> Void = { _ in }, refresh: (() async -> Void)? = nil) {
        self.content = content
        self.unreadCount = unreadCount
        self.openAlerts = openAlerts
        self.openSession = openSession
        self.refresh = refresh
    }

    init(summary: DashboardSummary) {
        self.content = .loaded(RealActiveSnapshot(generatedAt: nil, activeSessionCount: summary.activeSession == nil ? 0 : 1, activeSession: summary.activeSession, warnings: summary.warnings, requestID: nil, serverTime: nil))
        self.refresh = nil
    }

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                    header
                    bodyContent
                }
                .padding(BotaplataSpacing.md)
            }
            .refreshable { await refresh?() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Dashboard")
                .font(BotaplataTypography.largeTitle)
                .foregroundStyle(BotaplataColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: openAlerts) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: BotaplataSymbol.alerts)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BotaplataColors.textPrimary)
                        .frame(width: BotaplataTouch.minimum, height: BotaplataTouch.minimum)
                        .background(BotaplataColors.cardGlass, in: Circle())
                        .overlay(Circle().stroke(BotaplataColors.cardBorder, lineWidth: 1))
                    if unreadCount > 0 {
                        Text("\(min(unreadCount, 99))")
                            .font(.caption2.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(BotaplataColors.danger, in: Capsule())
                            .offset(x: 6, y: -4)
                    }
                }
            }
            .accessibilityLabel(unreadCount > 0 ? "Alertes, \(unreadCount) non lues" : "Alertes, aucune non lue")
        }
    }

    @ViewBuilder private var bodyContent: some View {
        switch content {
        case .idle, .loading:
            DashboardLoadingView()
        case .error(let message):
            PremiumErrorState(title: "Impossible de charger le Dashboard", message: message)
            PremiumSecondaryButton(title: "Réessayer") { Task { await refresh?() } }
        case .loaded(let snapshot):
            snapshotView(snapshot, cached: false, offline: false)
        case .loadedFromCache(let snapshot):
            snapshotView(snapshot, cached: true, offline: false)
        case .refreshing(let snapshot?):
            snapshotView(snapshot, cached: false, offline: false)
        case .partial(let snapshot):
            snapshotView(snapshot, cached: false, offline: false)
        case .stale(let snapshot):
            snapshotView(snapshot, cached: true, offline: false)
        case .offline(let snapshot?):
            snapshotView(snapshot, cached: true, offline: true)
        case .refreshing(nil), .offline(nil):
            PremiumOfflineBanner()
            PremiumErrorState(title: "Impossible de charger le Dashboard", message: "Vérifiez la connexion au serveur Botaplata.")
            PremiumSecondaryButton(title: "Réessayer") { Task { await refresh?() } }
        }
    }

    private func snapshotView(_ snapshot: RealActiveSnapshot, cached: Bool, offline: Bool) -> some View {
        LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            if offline { PremiumOfflineBanner() }
            if cached && !offline { WarningBanner(warning: Warning(id: "cache", severity: .information, title: "Dernier état connu affiché", message: "Les données proviennent du cache local pendant l'actualisation.")) }
            ForEach(snapshot.warnings) { WarningBanner(warning: $0) }
            DashboardHeroCard(snapshot: snapshot, cached: cached || offline)
            if unreadCount > 0 { DashboardAlertCard(unreadCount: unreadCount, openAlerts: openAlerts) }
            if let session = snapshot.activeSession {
                DashboardSessionCard(session: session, activeSessionCount: snapshot.activeSessionCount, openSession: openSession)
                DecisionSummaryCard(session: session)
                StrategyConditionsCard(decision: session.decision)
                PositionCard(session: session)
                ReconciliationCard(session: session)
                if let order = session.activeOrder { ActiveOrderCard(order: order) }
                SessionFinancialSummaryCard(session: session)
                FeeAwareCard(fee: session.feeAware, compact: true)
                HealthFreshnessCard(session: session, cached: cached || offline)
                DashboardRefreshFooter(snapshot: snapshot, session: session, cached: cached || offline)
            } else {
                PremiumEmptyState(title: "Aucune session active", message: "Les sessions Kraken disponibles apparaîtront ici.", systemImage: "tray")
                DashboardHealthEmptyCard(snapshot: snapshot, cached: cached || offline)
            }
        }
    }
}

private struct DashboardHeroCard: View {
    let snapshot: RealActiveSnapshot
    let cached: Bool
    var session: SessionDetail? { snapshot.activeSession }
    var body: some View {
        PremiumCard(variant: .hero) {
            VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                HStack(alignment: .top) {
                    IconBadge(symbol: "shield.lefthalf.filled", label: "Botaplata", color: BotaplataColors.primaryMint)
                    Spacer()
                    if cached { StatusPill(status: .neutral, text: "Dernier état connu") }
                    else if let session, session.runtimeHealth == .healthy, session.freshness.status == .fresh { LiveBadge() }
                    else if let session { StatusPill(status: DashboardPresentation.primaryBadgeStatus(session), text: DashboardPresentation.primaryBadgeText(session)) }
                }
                Text(DashboardPresentation.heroTitle(session))
                    .font(.title.weight(.bold))
                    .foregroundStyle(BotaplataColors.textPrimary)
                Text(DashboardPresentation.heroSubtitle(session))
                    .font(BotaplataTypography.body)
                    .foregroundStyle(BotaplataColors.textSecondary)
                HStack { if let session { ProviderBadge(provider: session.provider); FreshnessBadge(freshness: cached ? DataFreshness(status: .cached, updatedAt: session.freshness.updatedAt, source: .localCache) : session.freshness) } }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DashboardSessionCard: View {
    let session: SessionDetail; let activeSessionCount: Int?; let openSession: (String) -> Void
    var body: some View {
        Button { openSession(session.id) } label: {
            PremiumCard {
                VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                    HStack { Text("Session suivie").font(BotaplataTypography.cardTitle); Spacer(); Image(systemName: "chevron.right").foregroundStyle(BotaplataColors.textMuted) }
                    Text(session.pair).font(.title2.bold().monospacedDigit()).foregroundStyle(BotaplataColors.textPrimary)
                    row("Plateforme", session.provider.displayName)
                    row("Stratégie", session.strategyName ?? "Indisponible")
                    row("Analyse", RealSessionUIPresentation.analysisText(session))
                    row("Mode", RealSessionUIPresentation.executionModeText(session.executionMode))
                    if let count = activeSessionCount, count > 1 { Text("Plusieurs sessions actives signalées par le backend.").font(.caption).foregroundStyle(BotaplataColors.warning) }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Session suivie, \(session.pair.replacingOccurrences(of: "/", with: " ")), \(session.provider.displayName), \(DashboardPresentation.wording(for: session.lifecycle).title).")
        .accessibilityHint("Ouvre le détail réel de la session")
    }
}

private struct DashboardDecisionCard: View { let session: SessionDetail
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Décision actuelle").font(BotaplataTypography.cardTitle); HStack { StatusPill(status: DashboardPresentation.decisionBadgeStatus(session.lifecycle), text: DashboardPresentation.decisionBadgeText(session.lifecycle)); Spacer() }; if let favorable = session.decision.favorableConditions, let required = session.decision.requiredConditions { Text("\(favorable) / \(required) conditions favorables").font(BotaplataTypography.metricValue).monospacedDigit() }; Text(session.decision.detail).foregroundStyle(BotaplataColors.textSecondary); if session.decision.favorableConditions == nil { Text("Le détail des conditions sera affiché lorsque le backend le fournit.").font(.caption).foregroundStyle(BotaplataColors.textMuted) } } }.accessibilityElement(children: .combine) }
}

private struct DashboardPositionCard: View { let session: SessionDetail
    var body: some View { PremiumCard(variant: DashboardPresentation.pnlVariant(session.pnl?.netEstimated)) { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Position ouverte").font(BotaplataTypography.cardTitle); row("Quantité", session.position?.quantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Prix moyen exécuté", display(session.position?.averageExecutionPrice)); row("Prix de revient frais inclus", display(session.position?.costBasisPrice ?? session.feeAware.costBasisPrice)); row("Prix actuel", display(session.currentPrice)); row("Résultat net estimé", display(session.pnl?.netEstimated ?? session.feeAware.unrealizedPnLNetEstimatedQuote)); Text("Cette estimation tient compte des frais d'achat réels, des frais de vente estimés et du slippage estimé.").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } }.accessibilityElement(children: .combine) }
}

private struct DashboardOrderCard: View { let order: TradingOrderSummary
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Ordre actif").font(BotaplataTypography.cardTitle); StatusPill(status: order.status == .rejected ? .danger : order.status == .filled ? .success : .waiting, text: DashboardPresentation.orderStatusText(order.status)); row("Sens", DashboardPresentation.orderSideText(order.side)); row("Quantité demandée", order.requestedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Quantité exécutée", order.executedQuantity.map { FinancialFormatters.decimal($0, min: 2, max: 8) } ?? "Indisponible"); row("Prix limite ou moyen", display(order.limitPrice ?? order.averageExecutionPrice)); if let updated = order.updatedAt ?? order.createdAt { row("Dernière mise à jour", DashboardPresentation.time(updated)) }; Text(order.message).font(.caption).foregroundStyle(BotaplataColors.textSecondary) } }.accessibilityElement(children: .combine) }
}

private struct DashboardMarketAnalysisCard: View { let session: SessionDetail; let openSession: (String) -> Void
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Analyse du marché").font(BotaplataTypography.cardTitle); Text("Le graphique détaillé est disponible dans la session.").foregroundStyle(BotaplataColors.textSecondary); Text("L’historique de prix sera affiché lorsqu’il sera disponible.").font(.caption).foregroundStyle(BotaplataColors.textMuted); PremiumSecondaryButton(title: "Voir la session") { openSession(session.id) } } } }
}

private struct DashboardHealthCard: View { let session: SessionDetail; let cached: Bool
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("État de Botaplata").font(BotaplataTypography.cardTitle); row("Surveillance", DashboardPresentation.monitoringText(session.runtimeHealth)); row("Données", cached ? "Dernier état connu" : DashboardPresentation.freshnessText(session.freshness)); if let errors = session.monitoringConsecutiveErrors, errors > 0 { row("Erreurs", "\(errors) consécutives") } } }.accessibilityElement(children: .combine) }
}
private struct DashboardHealthEmptyCard: View { let snapshot: RealActiveSnapshot; let cached: Bool
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("État de Botaplata").font(BotaplataTypography.cardTitle); row("Serveur Botaplata", "Disponible"); row("Données", cached ? "Dernier état connu" : snapshot.generatedAt.map { "Actualisées à \(DashboardPresentation.time($0))" } ?? "Actualisation inconnue") } } }
}
private struct DashboardAlertCard: View { let unreadCount: Int; let openAlerts: () -> Void
    var body: some View { Button(action: openAlerts) { PremiumCard(variant: .warning) { HStack { VStack(alignment: .leading, spacing: 4) { Text("\(unreadCount) alertes non lues").font(BotaplataTypography.cardTitle).monospacedDigit(); Text("Voir les alertes").foregroundStyle(BotaplataColors.textSecondary) }; Spacer(); Image(systemName: "chevron.right") } } }.buttonStyle(.plain).accessibilityLabel("Alertes, \(unreadCount) non lues") }
}
private struct DashboardRefreshFooter: View { let snapshot: RealActiveSnapshot; let session: SessionDetail; let cached: Bool
    var body: some View { Text(cached ? "Dernier état connu affiché." : "Dernière actualisation : \(DashboardPresentation.lastRefresh(snapshot: snapshot, session: session))").font(.caption).foregroundStyle(BotaplataColors.textMuted).frame(maxWidth: .infinity, alignment: .center) }
}
private struct DashboardLoadingView: View { var body: some View { VStack(spacing: BotaplataSpacing.md) { PremiumSkeletonCard(); PremiumSkeletonCard(); PremiumSkeletonCard() } } }

private func row(_ key: String, _ value: String) -> some View { HStack(alignment: .firstTextBaseline) { Text(key).foregroundStyle(BotaplataColors.textSecondary); Spacer(minLength: BotaplataSpacing.sm); Text(value).foregroundStyle(BotaplataColors.textPrimary).multilineTextAlignment(.trailing).monospacedDigit() }.font(BotaplataTypography.body) }
private func display(_ amount: MoneyAmount?) -> String { let value = FinancialFormatters.money(amount); return value == "—" ? "Indisponible" : value }

extension DashboardPresentation {
    static func shouldShowPosition(_ position: OpenPosition?) -> Bool { guard let quantity = position?.quantity else { return false }; return quantity > 0 }
    static func heroTitle(_ session: SessionDetail?) -> String { guard let session else { return "Aucune session active." }; if session.runtimeHealth == .degraded { return "Surveillance perturbée." }; switch session.lifecycle { case .waitingBuy: return "Botaplata surveille le marché."; case .waitingBuyFill: return "Ordre d'achat en attente."; case .waitingSell, .positionOpen, .monitoringPosition: return "Position ouverte."; case .waitingSellFill: return "Ordre de vente en attente."; case .reconciliationPending: return "Vérification en cours."; default: return wording(for: session.lifecycle).title } }
    static func heroSubtitle(_ session: SessionDetail?) -> String { guard let session else { return "Les sessions Kraken disponibles apparaîtront ici." }; if session.runtimeHealth == .degraded { return "Botaplata rencontre actuellement un problème de surveillance." }; switch session.lifecycle { case .waitingBuy: return "Il cherche une opportunité sur \(session.pair)."; case .waitingBuyFill: return "Kraken n'a pas encore confirmé son exécution."; case .waitingSell, .positionOpen, .monitoringPosition: return "Botaplata surveille maintenant les conditions de sortie."; case .waitingSellFill: return "Botaplata attend la confirmation de Kraken."; case .reconciliationPending: return "Botaplata vérifie encore l'état de cet ordre sur Kraken."; default: return wording(for: session.lifecycle).text } }
    static func primaryBadgeStatus(_ session: SessionDetail) -> BadgeStatus { if session.runtimeHealth == .degraded { return .warning }; switch session.freshness.status { case .stale: return .warning; case .aging: return .waiting; default: return decisionBadgeStatus(session.lifecycle) } }
    static func primaryBadgeText(_ session: SessionDetail) -> String { if session.runtimeHealth == .degraded { return "À surveiller" }; switch session.freshness.status { case .stale: return "Données anciennes"; case .aging: return "Actualisation ralentie"; default: return decisionBadgeText(session.lifecycle) } }
    static func decisionBadgeStatus(_ lifecycle: SessionLifecycleState) -> BadgeStatus { switch lifecycle { case .waitingBuy: return .waiting; case .waitingSell, .positionOpen, .monitoringPosition: return .success; case .waitingBuyFill, .waitingSellFill, .reconciliationPending: return .warning; default: return .neutral } }
    static func decisionBadgeText(_ lifecycle: SessionLifecycleState) -> String { switch lifecycle { case .waitingBuy: return "Recherche une opportunité"; case .waitingBuyFill: return "Achat en attente"; case .waitingSell, .positionOpen, .monitoringPosition: return "Position ouverte"; case .waitingSellFill: return "Vente en attente"; case .reconciliationPending: return "Vérification en cours"; default: return wording(for: lifecycle).title } }
    static func orderStatusText(_ status: OrderStatus) -> String { switch status { case .submitted: return "Envoyé à Kraken"; case .open: return "En attente sur Kraken"; case .partiallyFilled: return "Exécution partielle"; case .reconciliationRequired: return "Vérification en cours"; case .reconciliationBlocked: return "Vérification nécessaire"; case .rejected: return "Ordre refusé"; case .filled: return "Confirmé par Kraken"; case .canceled: return "Annulé"; case .reconciliationFailed: return "Vérification échouée"; case .unknown: return "État inconnu" } }
    static func orderSideText(_ side: String) -> String { side.uppercased().contains("SELL") ? "Vente" : side.uppercased().contains("BUY") ? "Achat" : "Indisponible" }
    static func monitoringText(_ health: RuntimeHealthState) -> String { switch health { case .healthy: return "Fonctionne normalement"; case .degraded: return "À surveiller"; case .unavailable: return "Indisponible"; case .unknown: return "État inconnu" } }
    static func freshnessText(_ freshness: DataFreshness) -> String { switch freshness.status { case .fresh: return "Données à jour"; case .aging: return "Actualisation ralentie"; case .stale: return "Données anciennes"; case .cached: return "Dernier état connu"; case .unknown: return "Actualisation inconnue" } }
    static func pnlVariant(_ amount: MoneyAmount?) -> PremiumCardVariant { guard let value = amount?.value else { return .normal }; return value >= 0 ? .success : .danger }
    static func time(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateStyle = .none; f.timeStyle = .short; return f.string(from: date) }
    static func lastRefresh(snapshot: RealActiveSnapshot, session: SessionDetail) -> String { if let date = session.freshness.updatedAt ?? snapshot.generatedAt { return time(date) }; return "inconnue" }
}

#Preview("Dashboard nominal waiting_buy") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.waitingBuy, warnings: [], requestID: nil, serverTime: nil)), unreadCount: 0) } }
#Preview("Dashboard 3 conditions sur 4") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.waitingBuy, warnings: [], requestID: nil, serverTime: nil)), unreadCount: 2) } }
#Preview("Dashboard position ouverte") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.krakenDetail, warnings: [], requestID: nil, serverTime: nil)), unreadCount: 1) } }
#Preview("Dashboard BUY en attente") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.waitingBuyFill, warnings: [], requestID: nil, serverTime: nil)), unreadCount: 0) } }
#Preview("Dashboard offline avec cache") { NavigationStack { DashboardView(content: .offline(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.krakenDetail, warnings: [], requestID: nil, serverTime: nil)), unreadCount: 3) } }
#Preview("Dashboard aucune session") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 0, activeSession: nil, warnings: [], requestID: nil, serverTime: nil)), unreadCount: 0) } }
#Preview("Dashboard loading") { NavigationStack { DashboardView(content: .loading) } }
#Preview("Dashboard waiting buy") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.waitingBuy, warnings: [], requestID: nil, serverTime: nil))) } }
#Preview("Dashboard décision 3 sur 4") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.waitingBuyWithConditions, warnings: [], requestID: nil, serverTime: nil))) } }
#Preview("Dashboard position ouverte") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.krakenDetail, warnings: [], requestID: nil, serverTime: nil))) } }
#Preview("Dashboard ordre pending") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.waitingBuyFill, warnings: [], requestID: nil, serverTime: nil))) } }
#Preview("Dashboard réconciliation") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.reconciliationDetail, warnings: [], requestID: nil, serverTime: nil))) } }
#Preview("Dashboard données anciennes") { NavigationStack { DashboardView(content: .loaded(RealActiveSnapshot(generatedAt: PreviewFixtures.now, activeSessionCount: 1, activeSession: PreviewFixtures.staleDetail, warnings: PreviewFixtures.staleDetail.warnings, requestID: nil, serverTime: nil))) } }
