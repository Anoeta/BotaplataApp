import SwiftUI

struct DashboardView: View {
    let content: LoadedContent<RealActiveSnapshot>
    var unreadCount: Int = 0
    var openAlerts: () -> Void = {}
    var openSession: (String) -> Void = { _ in }
    var refresh: (() async -> Void)? = nil
    var historyStore: RealSessionHistoryStore? = nil
    var openAnalysis: (String) -> Void = { _ in }
    @Environment(RealStrategyExplanationStore.self) private var strategyStore

    init(content: LoadedContent<RealActiveSnapshot>, unreadCount: Int = 0, openAlerts: @escaping () -> Void = {}, openSession: @escaping (String) -> Void = { _ in }, refresh: (() async -> Void)? = nil, historyStore: RealSessionHistoryStore? = nil, openAnalysis: @escaping (String) -> Void = { _ in }) {
        self.content = content; self.unreadCount = unreadCount; self.openAlerts = openAlerts; self.openSession = openSession; self.refresh = refresh; self.historyStore = historyStore; self.openAnalysis = openAnalysis
    }

    init(summary: DashboardSummary) {
        content = .loaded(RealActiveSnapshot(generatedAt: nil, activeSessionCount: summary.activeSession == nil ? 0 : 1, activeSession: summary.activeSession, warnings: summary.warnings, requestID: nil, serverTime: nil))
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
                .safeAreaPadding(.bottom, BotaplataSpacing.md)
            }
            .refreshable { await refresh?() }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Botaplata").font(BotaplataTypography.largeTitle).accessibilityAddTraits(.isHeader)
                Text("SUPERVISION · LECTURE SEULE").tracking(1).font(BotaplataTypography.eyebrow).foregroundStyle(BotaplataColors.textSecondary)
            }
            Spacer()
            Button(action: openAlerts) {
                Image(systemName: unreadCount > 0 ? "bell.badge" : "bell")
                    .font(.title3).frame(width: 44, height: 44)
                    .background(BotaplataColors.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(BotaplataColors.border, lineWidth: 1))
            }
            .accessibilityLabel(unreadCount > 0 ? "Alertes, \(unreadCount) non lues" : "Alertes")
        }
        .foregroundStyle(BotaplataColors.textPrimary)
    }

    @ViewBuilder private var bodyContent: some View {
        switch content {
        case .idle, .loading:
            PremiumSkeletonCard(); PremiumSkeletonCard(); PremiumSkeletonCard()
        case .error(let message):
            PremiumErrorState(title: "Accueil indisponible", message: message)
            retry
        case .loaded(let snapshot), .partial(let snapshot):
            snapshotView(snapshot, cached: false, offline: false)
        case .loadedFromCache(let snapshot), .stale(let snapshot):
            snapshotView(snapshot, cached: true, offline: false)
        case .refreshing(let snapshot?):
            snapshotView(snapshot, cached: false, offline: false)
        case .offline(let snapshot?):
            snapshotView(snapshot, cached: true, offline: true)
        case .refreshing(nil):
            PremiumSkeletonCard()
        case .offline(nil):
            PremiumEmptyState(title: "Hors ligne", message: "Aucun état en cache n’est disponible. Actualisez lorsque la connexion revient.", systemImage: "wifi.slash")
            retry
        }
    }

    private var retry: some View { PremiumSecondaryButton(title: "Réessayer") { Task { await refresh?() } } }

    @ViewBuilder private func snapshotView(_ snapshot: RealActiveSnapshot, cached: Bool, offline: Bool) -> some View {
        if let session = snapshot.activeSession {
            SupervisionStrip(session: session, cached: cached, offline: offline)
            PremiumEngineCard(session: session, cached: cached)
            PremiumSessionMetricsGrid(session: session)
            PremiumMarketSection(session: session)
            decision(session: session, cached: cached)
            if let historyStore { PremiumRecentEventsSection(sessionID: session.id, store: historyStore) }
            PremiumPerformanceUnavailableCard()
            DisclosureGroup("Capital et détails financiers") { PremiumSessionPerformanceCard(session: session).padding(.top, 10) }.font(.subheadline.weight(.semibold))
            Button { openSession(session.id) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session suivie · \(session.pair)").font(.headline)
                        Text([session.provider.displayName, SessionArchivePresentation.strategy(name: session.strategyName, version: session.strategyVersion)].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }.padding(.vertical, 8).frame(minHeight: 44)
            }.buttonStyle(.plain)
            if let count = snapshot.activeSessionCount, count > 1 {
                Text("\(count) sessions actives : le backend sélectionne la session suivie.").font(.caption).foregroundStyle(BotaplataColors.warning)
            }
            if session.reconciliation != nil { ReconciliationCard(session: session) }
            if let order = session.activeOrder { ActiveOrderCard(order: order) }
            ForEach(snapshot.warnings + session.warnings) { WarningBanner(warning: $0) }
            Text("Snapshot généré : \(snapshot.generatedAt.map(HistoryPresentation.fullDate) ?? "date inconnue")")
                .font(.caption).foregroundStyle(BotaplataColors.textMuted)
        } else {
            if offline { PremiumOfflineBanner() }
            PremiumEmptyState(title: "Aucune session active", message: "Le backend ne signale aucune session Kraken réelle à suivre. Le graphique apparaît lorsqu’une session fournit ses bougies persistées.", systemImage: "chart.xyaxis.line")
            Text(cached ? "État en cache · santé actuelle inconnue" : "Réponse reçue · santé du bot inconnue")
                .font(.caption).foregroundStyle(BotaplataColors.textMuted)
            ForEach(snapshot.warnings) { WarningBanner(warning: $0) }
        }
    }

    private func decision(session: SessionDetail, cached: Bool) -> some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Dernière décision").font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                    Spacer()
                    Button("Analyse") { openAnalysis(session.id) }.font(.subheadline.bold()).frame(minHeight: 44)
                }
                if let explanation = strategyStore.explanation, explanation.sessionID == session.id {
                    Text(explanation.decision.label).font(.title3.bold())
                    Text(explanation.decision.summary).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary)
                    if cached || strategyStore.isOffline { Text("Dernière analyse connue").font(.caption).foregroundStyle(BotaplataColors.warning) }
                    if let close = explanation.analysis.candleCloseTime {
                        Text("Bougie clôturée · \(HistoryPresentation.fullDate(close))").font(.caption).foregroundStyle(BotaplataColors.textMuted)
                    }
                } else {
                    Text(session.decision.title).font(.title3.bold())
                    Text(session.decision.detail).font(.subheadline).foregroundStyle(BotaplataColors.textSecondary)
                    Text("Explication détaillée en attente du backend").font(.caption).foregroundStyle(BotaplataColors.textMuted)
                }
            }
        }
    }
}

struct SupervisionStrip: View {
    let session: SessionDetail
    let cached: Bool
    let offline: Bool
    private var health: SupervisionState { PremiumSupervisionPresentation.state(session: session, cached: cached) }
    private var status: BadgeStatus {
        switch health { case .healthy: .success; case .degraded: .warning; case .blocked: .danger; case .unknown: .neutral }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack { StatusPill(status: status, text: health.title + (cached && health == .blocked ? " · dernier état" : "")); Spacer(); connection }
                VStack(alignment: .leading) { StatusPill(status: status, text: health.title + (cached && health == .blocked ? " · dernier état" : "")); connection }
            }
            Text("Données : \(cached ? "dernier état connu" : SessionFreshnessPresentation.text(for: session.freshness))")
                .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
    private var connection: some View {
        Label(offline ? "Hors ligne" : cached ? "État en cache" : "Réponse reçue", systemImage: offline ? "wifi.slash" : "network")
            .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
    }
}

extension DashboardPresentation {
    static func shouldShowPosition(_ position: OpenPosition?) -> Bool { guard let quantity = position?.quantity else { return false }; return quantity > 0 }
    static func heroTitle(_ session: SessionDetail?) -> String { guard let session else { return "Aucune session active." }; if session.runtimeHealth == .degraded { return "Surveillance perturbée." }; switch session.lifecycle { case .waitingBuy: return "Botaplata surveille le marché."; case .preparingBuy: return "Botaplata prépare une intention d'achat."; case .waitingBuyFill: return "Ordre d'achat en attente."; case .waitingSell, .positionOpen, .monitoringPosition: return "Position ouverte."; case .waitingSellFill: return "Ordre de vente en attente."; case .reconciliationPending: return "Vérification en cours."; default: return wording(for: session.lifecycle).title } }
    static func heroSubtitle(_ session: SessionDetail?) -> String { guard let session else { return "Les sessions Kraken disponibles apparaîtront ici." }; if session.runtimeHealth == .degraded { return "Botaplata rencontre actuellement un problème de surveillance." }; switch session.lifecycle { case .waitingBuy: return "Il cherche une opportunité sur \(session.pair)."; case .preparingBuy: return "Botaplata prépare les contrôles avant achat."; case .waitingBuyFill: return "Kraken n'a pas encore confirmé son exécution."; case .waitingSell, .positionOpen, .monitoringPosition: return "Botaplata surveille maintenant les conditions de sortie."; case .waitingSellFill: return "Botaplata attend la confirmation de Kraken."; case .reconciliationPending: return "Botaplata vérifie encore l'état de cet ordre sur Kraken."; default: return wording(for: session.lifecycle).text } }
    static func primaryBadgeStatus(_ session: SessionDetail) -> BadgeStatus { if session.runtimeHealth == .degraded { return .warning }; switch session.freshness.status { case .fresh: return decisionBadgeStatus(session.lifecycle); case .aging: return .waiting; case .stale: return .warning; case .cached: return .neutral; case .unknown: return .neutral } }
    static func primaryBadgeText(_ session: SessionDetail) -> String { if session.runtimeHealth == .degraded { return "À surveiller" }; switch session.freshness.status { case .fresh: return decisionBadgeText(session.lifecycle); case .aging: return "Actualisation ralentie"; case .stale: return "Données anciennes"; case .cached: return "Dernier état connu"; case .unknown: return "Fraîcheur inconnue" } }
    static func decisionBadgeStatus(_ lifecycle: SessionLifecycleState) -> BadgeStatus { switch lifecycle { case .waitingBuy, .preparingBuy: return .waiting; case .waitingSell, .positionOpen, .monitoringPosition: return .success; case .waitingBuyFill, .waitingSellFill, .reconciliationPending: return .warning; default: return .neutral } }
    static func decisionBadgeText(_ lifecycle: SessionLifecycleState) -> String { switch lifecycle { case .waitingBuy: return "Recherche une opportunité"; case .preparingBuy: return "Préparation achat"; case .waitingBuyFill: return "Achat en attente"; case .waitingSell, .positionOpen, .monitoringPosition: return "Position ouverte"; case .waitingSellFill: return "Vente en attente"; case .reconciliationPending: return "Vérification en cours"; default: return wording(for: lifecycle).title } }
    static func orderStatusText(_ status: OrderStatus) -> String { switch status { case .submissionStarted: return "Préparation de l’ordre"; case .submitted: return "Envoyé à Kraken"; case .open: return "Ouvert · état local"; case .partiallyFilled: return "Exécution partielle"; case .reconciliationRequired: return "Vérification en cours"; case .reconciliationBlocked: return "Vérification nécessaire"; case .rejected: return "Ordre refusé"; case .filled: return "Confirmé par Kraken"; case .canceled: return "Annulé"; case .reconciliationFailed: return "Vérification échouée"; case .unknown: return "État inconnu" } }
    static func orderSideText(_ side: String) -> String { side.uppercased().contains("SELL") ? "Vente" : side.uppercased().contains("BUY") ? "Achat" : "Indisponible" }
    static func monitoringText(_ health: RuntimeHealthState) -> String { switch health { case .healthy: return "Fonctionne normalement"; case .degraded: return "À surveiller"; case .unavailable: return "Indisponible"; case .unknown: return "État inconnu" } }
    static func freshnessText(_ freshness: DataFreshness) -> String { SessionFreshnessPresentation.text(for: freshness) }
    static func pnlVariant(_ amount: MoneyAmount?) -> PremiumCardVariant { guard let value = amount?.value else { return .normal }; return value >= 0 ? .success : .danger }
    static func time(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateStyle = .none; f.timeStyle = .short; return f.string(from: date) }
    static func lastRefresh(snapshot: RealActiveSnapshot, session: SessionDetail) -> String { if let date = session.freshness.updatedAt ?? snapshot.generatedAt { return time(date) }; return "inconnue" }
}
