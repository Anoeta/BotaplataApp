import Foundation

struct RealSessionsPage: Equatable, Sendable, Codable { let items: [SessionSummary]; let pagination: RealSessionsPagination; let warnings: [Warning]; let serverTime: Date? }
struct RealSessionsPagination: Equatable, Sendable, Codable { let page: Int; let pageSize: Int; let total: Int; let hasMore: Bool }

extension RealSessionsPageDTO { func mapped(warnings apiWarnings: [APIWarning] = [], serverTime: Date? = nil) -> RealSessionsPage { RealSessionsPage(items: items.map { $0.mapped() }, pagination: RealSessionsPagination(page: pagination.page, pageSize: pagination.pageSize, total: pagination.total, hasMore: pagination.hasMore), warnings: apiWarnings.map(Warning.init(api:)), serverTime: serverTime) } }
extension RealSessionSummaryDTO { func mapped() -> SessionSummary { let quote = resolvedQuoteAsset(displaySymbol: displaySymbol, symbol: symbol); let hasPosition = position?.hasPositiveQuantity == true; return SessionSummary(id: id, pair: displaySymbol ?? symbol ?? name ?? id, provider: TradingProvider(backend: provider), providerLabel: providerLabel, backendStatus: status, lifecycle: SessionLifecycleState(backend: lifecycleState), runtimeHealth: RuntimeHealthState(backend: monitoring?.health), freshness: freshness.mapped(generatedAt: updatedAt), executionMode: ExecutionMode(backend: executionMode), isPositionOpen: hasPosition, positionStatus: position?.status, baseQuantity: hasPosition ? position?.baseQty?.value : nil, currentPrice: position?.currentPrice.money(quote), activeOrderSide: activeOrder?.side, activeOrderStatus: activeOrder?.status.map(OrderStatus.init(backend:)), strategyName: strategy?.displayName ?? strategy?.key, startedAt: startedAt, stoppedAt: stoppedAt, updatedAt: updatedAt, unrealizedPnLQuote: hasPosition ? unrealizedPnlQuote.money(quote) : nil, realizedPnLNetQuote: realizedPnlNetQuote.money(quote)) } }
extension RealSessionDetailDTO { func mapped(warnings apiWarnings: [APIWarning] = []) -> SessionDetail { let pair = displaySymbol ?? symbol ?? name ?? id; let quote = resolvedQuoteAsset(displaySymbol: displaySymbol, symbol: symbol, fallback: quoteAsset ?? market?.quoteAsset); let lifecycle = SessionLifecycleState(backend: lifecycleState); let fee = feeAware?.mapped(currency: quote) ?? .empty; let hasPosition = position?.hasPositiveQuantity == true; let gross = hasPosition ? (pnl?.unrealizedPnlQuote.money(quote) ?? fee.unrealizedPnLGrossQuote) : nil; let net = hasPosition ? (pnl?.unrealizedPnlNetEstimatedQuote.money(quote) ?? fee.unrealizedPnLNetEstimatedQuote) : nil; let realized = pnl?.realizedPnlNetQuote.money(quote) ?? fee.realizedPnLNetQuote; return SessionDetail(id: id, pair: pair, provider: TradingProvider(backend: provider), providerLabel: providerLabel, backendStatus: status, lifecycle: lifecycle, runtimeHealth: RuntimeHealthState(backend: monitoring?.health), monitoringConsecutiveErrors: monitoring?.consecutiveErrors, freshness: freshness.mapped(generatedAt: updatedAt), executionMode: ExecutionMode(backend: executionMode), startedAt: startedAt, stoppedAt: stoppedAt, strategyName: strategyDisplayName ?? strategyKey, currentPrice: market?.currentPrice.money(quote), position: position?.mapped(pair: pair, currency: quote), decision: decision?.mapped(currency: quote, lifecycle: lifecycle) ?? StrategyDecisionSummary(title: DashboardPresentation.wording(for: lifecycle).title, detail: DashboardPresentation.wording(for: lifecycle).text, favorableConditions: nil, requiredConditions: nil), activeOrder: activeOrder?.mapped(currency: quote), reconciliation: reconciliation?.mapped(), pnl: (gross != nil || net != nil || realized != nil) ? ProfitAndLoss(gross: gross, netEstimated: net, realizedNet: realized) : nil, feeAware: fee, warnings: apiWarnings.map(Warning.init(api:))) } }
extension RealReconciliationDTO { func mapped() -> Warning? { guard required == true || state == "reconciliation_pending" || state == "pending" || state == "blocked" else { return nil }; return Warning(id: "reconciliation_pending", severity: .information, title: state == "blocked" ? "Vérification nécessaire" : "Vérification en cours", message: "Botaplata vérifie encore l'état de cet ordre sur Kraken.") } }
extension Warning {
    init(api: APIWarning) {
        self.init(id: api.code, severity: api.code == "monitoring_degraded" || api.code == "stale_session_data" ? .warning : .information, title: Self.title(for: api.code), message: api.message)
    }
    static func title(for code: String) -> String {
        switch code { case "monitoring_degraded": return "Surveillance perturbée"; case "stale_session_data": return "Données à vérifier"; case "multiple_active_real_sessions": return "Plusieurs sessions actives"; default: return "Information Botaplata" }
    }
}
extension ExecutionMode { init(backend: String?) { switch backend { case "real": self = .real; case "spot_production", "spotProduction": self = .spotProduction; case "legacy_read_only": self = .legacyReadOnly; case "demo_fixture": self = .demoFixture; default: self = .unknown } } }
private func resolvedQuoteAsset(displaySymbol: String?, symbol: String?, fallback: String? = nil) -> String {
    fallback ?? quoteAsset(from: displaySymbol ?? symbol) ?? "USDC"
}

private func quoteAsset(from pair: String?) -> String? { pair?.split(separator: "/").last.map(String.init) }

extension RealDecisionDTO {
    func mapped(currency: String = "USDC", lifecycle: SessionLifecycleState = .unknown) -> StrategyDecisionSummary {
        let fallback = DashboardPresentation.wording(for: lifecycle)
        return StrategyDecisionSummary(
            title: title ?? decision.map(Self.localTitle(for:)) ?? fallback.title,
            detail: detail ?? advice.first ?? fallback.text,
            favorableConditions: favorableConditions,
            requiredConditions: requiredConditions,
            code: decision,
            score: score?.value,
            scoreMin: scoreMin?.value,
            controller: controller,
            blockers: blockers,
            buyConditions: buyConditions.map { $0.mapped() },
            sellConditions: sellConditions.map { $0.mapped() },
            advice: advice,
            price: price.money(currency),
            createdAt: createdAt
        )
    }
    private static func localTitle(for code: String) -> String {
        switch code.lowercased() { case "buy", "buy_signal", "signal_buy": return "Signal d'achat"; case "sell", "sell_signal", "signal_sell": return "Signal de vente"; case "hold", "wait", "waiting_buy": return "Aucune action"; default: return "Décision actuelle" }
    }
}
extension RealStrategyConditionDTO { func mapped() -> StrategyConditionSummary { StrategyConditionSummary(key: key, label: label, state: state, value: value, threshold: threshold, detail: detail) } }

extension RealSessionSummaryPositionDTO { var hasPositiveQuantity: Bool { (baseQty?.value ?? 0) > 0 && (isOpen ?? true) } }
extension RealPositionDTO {
    var hasPositiveQuantity: Bool { (baseQty?.value ?? 0) > 0 }
    func mapped(pair: String, currency: String) -> OpenPosition? {
        guard hasPositiveQuantity else { return nil }
        return OpenPosition(pair: pair, quantity: baseQty?.value, averageExecutionPrice: (averageExecutionPrice ?? entryPrice).money(currency), costBasisPrice: costBasisPrice.money(currency), id: id, status: status, side: side, entryPrice: entryPrice.money(currency), currentPrice: currentPrice.money(currency), estimatedValueQuote: estimatedValueQuote.money(currency), unrealizedPnLQuote: unrealizedPnlQuote.money(currency), openedAt: openedAt, origin: origin, reconciliationPending: reconciliationPending)
    }
}
