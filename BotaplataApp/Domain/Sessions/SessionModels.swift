import Foundation

struct SessionSummary: Identifiable, Equatable, Sendable, Codable {
    let id: String; let pair: String; let provider: TradingProvider; var providerLabel: String? = nil; var backendStatus: String? = nil; let lifecycle: SessionLifecycleState; let runtimeHealth: RuntimeHealthState; let freshness: DataFreshness; let executionMode: ExecutionMode
    var isPositionOpen: Bool? = nil; var positionStatus: String? = nil; var baseQuantity: Decimal? = nil; var currentPrice: MoneyAmount? = nil; var activeOrderSide: String? = nil; var activeOrderStatus: OrderStatus? = nil; var strategyName: String? = nil; var startedAt: Date? = nil; var stoppedAt: Date? = nil; var updatedAt: Date? = nil; var unrealizedPnLQuote: MoneyAmount? = nil; var realizedPnLNetQuote: MoneyAmount? = nil
    var isHistorical: Bool { lifecycle == .stopped || stoppedAt != nil || backendStatus == "stopped" }
}

struct SessionDetail: Identifiable, Equatable, Sendable, Codable {
    let id: String; let pair: String; let provider: TradingProvider; var providerLabel: String? = nil; var backendStatus: String? = nil; let lifecycle: SessionLifecycleState; let runtimeHealth: RuntimeHealthState; var monitoringConsecutiveErrors: Int? = nil; let freshness: DataFreshness; var executionMode: ExecutionMode = .unknown; var startedAt: Date? = nil; var stoppedAt: Date? = nil; var strategyName: String? = nil; let currentPrice: MoneyAmount?; let position: OpenPosition?; let decision: StrategyDecisionSummary; let activeOrder: TradingOrderSummary?; var reconciliation: Warning? = nil; let pnl: ProfitAndLoss?; let feeAware: FeeAwareSummary; let warnings: [Warning]
}
