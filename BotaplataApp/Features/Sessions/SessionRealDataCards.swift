import SwiftUI

enum RealSessionUIPresentation {
    struct Line: Equatable { let label: String; let value: String }

    static func executionModeText(_ mode: ExecutionMode) -> String {
        switch mode { case .real, .spotProduction: "Réel"; case .legacyReadOnly: "Lecture seule"; case .demoFixture: "Démo"; case .unknown: "À confirmer" }
    }

    static func analysisText(_ session: SessionDetail) -> String { "Toutes les 5 minutes" }
    static func orderSideText(_ side: String) -> String { side.uppercased().contains("SELL") ? "Vente" : side.uppercased().contains("BUY") ? "Achat" : "Ordre" }
    static func orderStatusText(_ status: OrderStatus) -> String { status.label }
    static func shouldShowPosition(_ position: OpenPosition?) -> Bool { (position?.quantity ?? 0) > 0 }
    static func hasReconciliation(_ session: SessionDetail) -> Bool { session.reconciliation != nil || session.lifecycle == .reconciliationPending || session.activeOrder?.status == .reconciliationRequired || session.activeOrder?.status == .reconciliationBlocked || session.activeOrder?.status == .reconciliationFailed }

    static func decisionLines(_ decision: StrategyDecisionSummary) -> [Line] {
        var lines: [Line] = []
        if let favorable = decision.favorableConditions, let required = decision.requiredConditions { lines.append(.init(label: "Conditions", value: "\(favorable) conditions favorables sur \(required)")) }
        if let score = decision.score, let scoreMin = decision.scoreMin { lines.append(.init(label: "Score", value: "\(FinancialFormatters.decimal(score, min: 0, max: 4)) / \(FinancialFormatters.decimal(scoreMin, min: 0, max: 4))")) }
        if let controller = decision.controller, !controller.isEmpty { lines.append(.init(label: "Contrôleur", value: controller)) }
        if let created = decision.createdAt { lines.append(.init(label: "Décision calculée", value: HistoryPresentation.time(created))) }
        if decision.price?.value != nil { lines.append(.init(label: "Prix analysé", value: FinancialFormatters.money(decision.price))) }
        return lines
    }

    static func conditionSections(_ decision: StrategyDecisionSummary) -> [(title: String, items: [StrategyConditionSummary])] {
        [("Conditions d’achat", decision.buyConditions), ("Conditions de vente", decision.sellConditions)].filter { !$0.items.isEmpty }
    }

    static func positionLines(session: SessionDetail) -> [Line] {
        guard let position = session.position, shouldShowPosition(position) else { return [] }
        var lines: [Line] = []
        if let q = position.quantity { lines.append(.init(label: "Quantité", value: "\(FinancialFormatters.decimal(q, min: 2, max: 8)) \(session.pair.split(separator: "/").first.map(String.init) ?? "")")) }
        let entry = position.entryPrice
        let average = position.averageExecutionPrice
        if entry?.value != nil, entry?.value != average?.value { lines.append(.init(label: "Prix d’entrée", value: FinancialFormatters.money(entry))) }
        if average?.value != nil { lines.append(.init(label: "Prix moyen exécuté", value: FinancialFormatters.money(average))) }
        let cost = position.costBasisPrice?.value != nil ? position.costBasisPrice : session.feeAware.costBasisPrice
        if cost?.value != nil { lines.append(.init(label: "Prix de revient frais inclus", value: FinancialFormatters.money(cost))) }
        let current = position.currentPrice?.value != nil ? position.currentPrice : session.currentPrice
        if current?.value != nil { lines.append(.init(label: "Prix actuel", value: FinancialFormatters.money(current))) }
        if position.estimatedValueQuote?.value != nil { lines.append(.init(label: "Valeur estimée", value: FinancialFormatters.money(position.estimatedValueQuote))) }
        return lines
    }

    static func financialRows(session: SessionDetail) -> [Line] {
        var rows: [Line] = []
        let hasPosition = shouldShowPosition(session.position)
        if hasPosition, session.pnl?.netEstimated?.value != nil { rows.append(.init(label: "Résultat net estimé", value: FinancialFormatters.money(session.pnl?.netEstimated))) }
        if hasPosition, session.pnl?.gross?.value != nil { rows.append(.init(label: "Résultat latent brut", value: FinancialFormatters.money(session.pnl?.gross))) }
        if session.pnl?.realizedNet?.value != nil { rows.append(.init(label: "Résultat réalisé net", value: FinancialFormatters.money(session.pnl?.realizedNet))) }
        return rows
    }

    static func feeAwareRows(_ fee: FeeAwareSummary) -> [Line] {
        [
            ("Frais d’achat réels", money(fee.buyFeeQuote)), ("Taux de frais effectif", fee.buyFeeRateEffective.map { FinancialFormatters.percent($0) }),
            ("Frais de vente estimés", money(fee.estimatedSellFeeQuote)), ("Source de l’estimation", fee.estimatedSellFeeSource),
            ("Slippage estimé", fee.estimatedSlippageRate.map { FinancialFormatters.percent($0) }), ("Frais estimés du cycle", money(fee.totalEstimatedCycleFeesQuote)),
            ("Prix de rentabilité", money(fee.breakEvenPrice)), ("Prix minimum rentable", money(fee.minimumProfitableExitPrice))
        ].compactMap { label, value in value.map { Line(label: label, value: $0) } }
    }
    private static func money(_ amount: MoneyAmount?) -> String? { amount?.value == nil ? nil : FinancialFormatters.money(amount) }
}

struct DecisionSummaryCard: View { let session: SessionDetail; var detailed = false
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Décision actuelle").font(BotaplataTypography.cardTitle); Text(session.decision.title).font(.headline); Text(session.decision.detail).foregroundStyle(BotaplataColors.textSecondary); ForEach(RealSessionUIPresentation.decisionLines(session.decision), id: \.label) { PremiumKeyValueRow(label: $0.label, value: $0.value, monospaced: true) }; if detailed { ForEach(session.decision.advice, id: \.self) { Text($0).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } } }.accessibilityElement(children: .combine) }
}

struct StrategyConditionsCard: View { let decision: StrategyDecisionSummary
    var hasContent: Bool { !decision.buyConditions.isEmpty || !decision.sellConditions.isEmpty || !decision.blockers.isEmpty }
    var body: some View { if hasContent { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Conditions de la stratégie").font(BotaplataTypography.cardTitle); ForEach(RealSessionUIPresentation.conditionSections(decision), id: \.title) { section in VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text(section.title).font(.subheadline.weight(.semibold)); ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in conditionRow(item) } } }; if !decision.blockers.isEmpty { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Éléments bloquants").font(.subheadline.weight(.semibold)); ForEach(decision.blockers, id: \.self) { Text($0).font(BotaplataTypography.body).foregroundStyle(BotaplataColors.textSecondary).accessibilityLabel("Élément bloquant. \($0)") } } } } }.accessibilityElement(children: .combine) } }
    func conditionRow(_ item: StrategyConditionSummary) -> some View { VStack(alignment: .leading, spacing: 3) { HStack { Text(item.label ?? item.key ?? "Condition").foregroundStyle(BotaplataColors.textPrimary); Spacer(); StatusPill(status: item.presentationState == "Favorable" ? .success : item.presentationState == "Défavorable" ? .danger : .waiting, text: item.presentationState) }; if let value = item.value { PremiumKeyValueRow(label: "Valeur", value: value, monospaced: true) }; if let threshold = item.threshold { PremiumKeyValueRow(label: "Seuil", value: threshold, monospaced: true) }; if let detail = item.detail { Text(detail).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } }
}

struct PositionCard: View { let session: SessionDetail
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { if RealSessionUIPresentation.shouldShowPosition(session.position) { Text("Position ouverte").font(BotaplataTypography.cardTitle); ForEach(RealSessionUIPresentation.positionLines(session: session), id: \.label) { PremiumKeyValueRow(label: $0.label, value: $0.value, monospaced: true) } } else { Text("Aucune position ouverte").font(BotaplataTypography.cardTitle); Text("Botaplata cherche encore une opportunité d’achat.").foregroundStyle(BotaplataColors.textSecondary) } } }.accessibilityElement(children: .combine) }
}

struct SessionFinancialSummaryCard: View { let session: SessionDetail
    var rows: [RealSessionUIPresentation.Line] { RealSessionUIPresentation.financialRows(session: session) }
    var body: some View { if !rows.isEmpty { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Résultats financiers").font(BotaplataTypography.cardTitle); ForEach(rows, id: \.label) { PremiumKeyValueRow(label: $0.label, value: $0.value, monospaced: true) }; Text("Le résultat net estimé tient compte des frais connus et des estimations fournies par le serveur Botaplata.").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } }.accessibilityElement(children: .combine) } }
}

struct FeeAwareCard: View { let fee: FeeAwareSummary; var compact = false
    var rows: [RealSessionUIPresentation.Line] { RealSessionUIPresentation.feeAwareRows(fee) }
    var body: some View { if !rows.isEmpty { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Frais / rentabilité").font(BotaplataTypography.cardTitle); ForEach(rows, id: \.label) { PremiumKeyValueRow(label: $0.label, value: $0.value, monospaced: true) }; if !compact { Text("Ces valeurs sont fournies par le serveur Botaplata. Elles ne sont pas recalculées sur l’iPhone.").font(.caption).foregroundStyle(BotaplataColors.textSecondary) } } } } }
}

struct ActiveOrderCard: View { let order: TradingOrderSummary
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Ordre actif").font(BotaplataTypography.cardTitle); Text(RealSessionUIPresentation.orderSideText(order.side)).font(.headline); StatusPill(status: order.status == .filled ? .success : order.status == .rejected ? .danger : .waiting, text: RealSessionUIPresentation.orderStatusText(order.status)); if let v = order.requestedQuantity { PremiumKeyValueRow(label: "Quantité demandée", value: FinancialFormatters.decimal(v, min: 2, max: 8), monospaced: true) }; if let v = order.executedQuantity { PremiumKeyValueRow(label: "Quantité exécutée", value: FinancialFormatters.decimal(v, min: 2, max: 8), monospaced: true) }; if order.limitPrice?.value != nil { PremiumKeyValueRow(label: "Prix limite", value: FinancialFormatters.money(order.limitPrice), monospaced: true) }; if order.averageExecutionPrice?.value != nil { PremiumKeyValueRow(label: "Prix moyen exécuté", value: FinancialFormatters.money(order.averageExecutionPrice), monospaced: true) }; if let updated = order.updatedAt ?? order.createdAt { PremiumKeyValueRow(label: "Dernière mise à jour", value: HistoryPresentation.fullDate(updated), monospaced: true) }; Text(order.message).font(.caption).foregroundStyle(BotaplataColors.textSecondary) } }.accessibilityElement(children: .combine) }
}

struct ReconciliationCard: View { let session: SessionDetail
    var body: some View { if RealSessionUIPresentation.hasReconciliation(session) { PremiumCard(variant: .warning) { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Vérification de l’ordre").font(BotaplataTypography.cardTitle); Text("Botaplata vérifie encore l’état de cet ordre sur Kraken.").foregroundStyle(BotaplataColors.textSecondary); if let order = session.activeOrder { PremiumKeyValueRow(label: "État", value: RealSessionUIPresentation.orderStatusText(order.status), monospaced: false); PremiumKeyValueRow(label: "Identifiant de l’ordre", value: String(order.id.suffix(8)), monospaced: true); if let updated = order.updatedAt ?? order.createdAt { PremiumKeyValueRow(label: "Dernière vérification", value: HistoryPresentation.fullDate(updated), monospaced: true) } }; if let warning = session.reconciliation { Text(warning.message).font(.caption).foregroundStyle(BotaplataColors.textMuted) } } }.accessibilityElement(children: .combine) } }
}

struct HealthFreshnessCard: View { let session: SessionDetail; var cached = false
    var body: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("État de Botaplata").font(BotaplataTypography.cardTitle); PremiumKeyValueRow(label: "Surveillance", value: session.runtimeHealth == .healthy ? "Fonctionne normalement" : session.runtimeHealth.label, monospaced: false); PremiumKeyValueRow(label: "Données", value: cached ? "Dernier état connu" : freshnessText(session.freshness), monospaced: false); if let date = session.decision.createdAt { PremiumKeyValueRow(label: "Dernière décision", value: freshnessText(DataFreshness(status: .fresh, updatedAt: date, source: .backend)), monospaced: false) }; if let errors = session.monitoringConsecutiveErrors, errors > 0 { Text("\(errors) erreurs de surveillance consécutives").foregroundStyle(BotaplataColors.warning) } } }.accessibilityElement(children: .combine) }
}
