import Foundation

extension RealActiveSnapshotDTO {
    func mapped(warnings apiWarnings: [APIWarning] = [], requestID: String? = nil, serverTime: Date? = nil) -> RealActiveSnapshot {
        RealActiveSnapshot(generatedAt: generatedAt, activeSessionCount: activeSessionCount, activeSession: activeSession?.mapped(), warnings: apiWarnings.map { Warning(id: $0.code, severity: $0.code == "multiple_active_real_sessions" ? .warning : .information, title: $0.code == "multiple_active_real_sessions" ? "Plusieurs sessions actives" : $0.code, message: $0.message) }, requestID: requestID, serverTime: serverTime)
    }
}

extension RealActiveSessionDTO {
    func mapped() -> SessionDetail {
        let pair = displaySymbol ?? symbol ?? name ?? id
        let lifecycle = SessionLifecycleState(backend: lifecycleState)
        let health = RuntimeHealthState(backend: monitoring?.health)
        let quote = market?.quoteAsset ?? "USDC"
        let fee = feeAware?.mapped(currency: quote) ?? FeeAwareSummary.empty
        return SessionDetail(id: id, pair: pair, provider: TradingProvider(backend: provider), lifecycle: lifecycle, runtimeHealth: health, freshness: freshness.mapped(generatedAt: nil), currentPrice: market?.currentPrice.money(quote), position: position?.mapped(pair: pair, currency: quote), decision: decision?.mapped() ?? StrategyDecisionSummary(title: DashboardPresentation.wording(for: lifecycle).title, detail: DashboardPresentation.wording(for: lifecycle).text, favorableConditions: nil, requiredConditions: nil), activeOrder: activeOrder?.mapped(currency: quote), pnl: ProfitAndLoss(gross: fee.unrealizedPnLGrossQuote, netEstimated: fee.unrealizedPnLNetEstimatedQuote, realizedNet: nil), feeAware: fee, warnings: [])
    }
}

extension Optional where Wrapped == RealFreshnessDTO { func mapped(generatedAt: Date?) -> DataFreshness { guard let f = self else { return DataFreshness(status: .unknown, updatedAt: generatedAt, source: .backend) }; return DataFreshness(status: FreshnessStatus(backend: f.status), updatedAt: f.updatedAt ?? f.snapshotGeneratedAt ?? generatedAt, source: .backend) } }
extension RealDecisionDTO { func mapped() -> StrategyDecisionSummary { StrategyDecisionSummary(title: title ?? "Décision actuelle", detail: detail ?? "Décision indisponible.", favorableConditions: favorableConditions, requiredConditions: requiredConditions) } }
extension RealPositionDTO { func mapped(pair: String, currency: String) -> OpenPosition { OpenPosition(pair: pair, quantity: baseQty?.value, averageExecutionPrice: averageExecutionPrice.money(currency), costBasisPrice: costBasisPrice.money(currency)) } }
extension RealOrderDTO { func mapped(currency: String) -> TradingOrderSummary { TradingOrderSummary(id: id ?? krakenOrderID ?? UUID().uuidString, side: side ?? "—", status: OrderStatus(backend: status), message: "Ordre \(side ?? "") \(status ?? "") sur Kraken.".trimmingCharacters(in: .whitespaces)) } }
extension RealFeeAwareDTO { func mapped(currency: String) -> FeeAwareSummary { FeeAwareSummary(executionPrice: executionPrice.money(currency), costBasisPrice: costBasisPrice.money(currency), buyFeeQuote: buyFeeQuote.money(currency), buyFeeRateEffective: buyFeeRateEffective?.value, estimatedSellFeeQuote: estimatedSellFeeQuote.money(currency), estimatedSellFeeRate: estimatedSellFeeRate?.value, estimatedSellFeeSource: estimatedSellFeeSource, breakEvenPrice: breakEvenPrice.money(currency), minimumProfitableExitPrice: minimumProfitableExitPrice.money(currency), minimumNetProfitRate: minimumNetProfitRate?.value, estimatedSlippageRate: estimatedSlippageRate?.value, unrealizedPnLGrossQuote: unrealizedPnlGrossQuote.money(currency), unrealizedPnLNetEstimatedQuote: unrealizedPnlNetEstimatedQuote.money(currency), realizedPnLNetQuote: nil, totalEstimatedCycleFeesQuote: totalCycleFeesEstimatedQuote.money(currency), liquidityRole: liquidityRoleLabel ?? liquidityRole) } }
extension Optional where Wrapped == DecimalString { func money(_ currency: String) -> MoneyAmount? { guard let value = self?.value else { return nil }; return MoneyAmount(value, currency: currency) } }
extension FeeAwareSummary { static let empty = FeeAwareSummary(executionPrice: nil, costBasisPrice: nil, buyFeeQuote: nil, buyFeeRateEffective: nil, estimatedSellFeeQuote: nil, estimatedSellFeeRate: nil, estimatedSellFeeSource: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, minimumNetProfitRate: nil, estimatedSlippageRate: nil, unrealizedPnLGrossQuote: nil, unrealizedPnLNetEstimatedQuote: nil, realizedPnLNetQuote: nil, totalEstimatedCycleFeesQuote: nil, liquidityRole: nil) }
extension SessionLifecycleState { init(backend: String?) { switch backend { case "waiting_buy": self = .waitingBuy; case "waiting_buy_fill": self = .waitingBuyFill; case "waiting_sell": self = .waitingSell; case "waiting_sell_fill": self = .waitingSellFill; case "reconciliation_pending": self = .reconciliationPending; case "stopped": self = .stopped; case "unknown": self = .unknown; default: self = .unknown } } }
extension RuntimeHealthState { init(backend: String?) { switch backend { case "healthy": self = .healthy; case "degraded": self = .degraded; case "unknown": self = .unknown; default: self = .unknown } } }
extension FreshnessStatus { init(backend: String?) { switch backend { case "fresh": self = .fresh; case "aging": self = .aging; case "stale": self = .stale; case "unknown": self = .unknown; default: self = .unknown } } }
extension TradingProvider { init(backend: String?) { self = backend == "kraken" ? .kraken : .unknown } }
extension OrderStatus { init(backend: String?) { switch backend { case "submitted": self = .submitted; case "open": self = .open; case "partially_filled": self = .partiallyFilled; case "filled": self = .filled; case "reconciliation_required": self = .reconciliationRequired; case "rejected": self = .rejected; case "canceled", "cancelled": self = .canceled; default: self = .unknown } } }
