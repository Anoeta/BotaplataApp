import Foundation

struct DecimalString: Codable, Equatable, Sendable {
    let value: Decimal
    init(_ value: Decimal) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { throw DecodingError.valueNotFound(String.self, .init(codingPath: decoder.codingPath, debugDescription: "Decimal string is null")) }
        let raw = try c.decode(String.self)
        guard let decimal = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid decimal string")
        }
        value = decimal
    }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(NSDecimalNumber(decimal: value).stringValue) }
}

struct RealActiveSnapshotDTO: Codable, Equatable, Sendable {
    let generatedAt: Date?
    let dataSource: String?
    let executionMode: String?
    let activeSessionCount: Int?
    let activeSession: RealActiveSessionDTO?
    enum CodingKeys: String, CodingKey { case generatedAt = "generated_at", dataSource = "data_source", executionMode = "execution_mode", activeSessionCount = "active_session_count", activeSession = "active_session" }
}

struct RealActiveSessionDTO: Codable, Equatable, Sendable {
    let id: String; let name: String?; let provider: String?; let providerLabel: String?; let symbol: String?; let displaySymbol: String?; let status: String?; let lifecycleState: String?
    let monitoring: RealMonitoringDTO?; let freshness: RealFreshnessDTO?; let market: RealMarketDTO?; let decision: RealDecisionDTO?; let position: RealPositionDTO?; let activeOrder: RealOrderDTO?; let reconciliation: RealReconciliationDTO?; let feeAware: RealFeeAwareDTO?
    enum CodingKeys: String, CodingKey { case id, name, provider, symbol, status, monitoring, freshness, market, decision, position, reconciliation; case providerLabel = "provider_label", displaySymbol = "display_symbol", lifecycleState = "lifecycle_state", activeOrder = "active_order", feeAware = "fee_aware" }
}
struct RealMonitoringDTO: Codable, Equatable, Sendable { let health: String?; let lastSuccessAt: Date?; let lastErrorAt: Date?; let consecutiveErrors: Int?; enum CodingKeys: String, CodingKey { case health; case lastSuccessAt = "last_success_at", lastErrorAt = "last_error_at", consecutiveErrors = "consecutive_errors" } }
struct RealFreshnessDTO: Codable, Equatable, Sendable { let snapshotGeneratedAt: Date?; let updatedAt: Date?; let ageSeconds: Int?; let status: String?; enum CodingKeys: String, CodingKey { case status; case snapshotGeneratedAt = "snapshot_generated_at", updatedAt = "updated_at", ageSeconds = "age_seconds" } }
struct RealMarketDTO: Codable, Equatable, Sendable { let currentPrice: DecimalString?; let quoteAsset: String?; let updatedAt: Date?; enum CodingKeys: String, CodingKey { case currentPrice = "current_price", quoteAsset = "quote_asset", updatedAt = "updated_at" } }
struct RealDecisionDTO: Codable, Equatable, Sendable { let title: String?; let detail: String?; let favorableConditions: Int?; let requiredConditions: Int?; enum CodingKeys: String, CodingKey { case title, detail; case favorableConditions = "favorable_conditions", requiredConditions = "required_conditions" } }
struct RealPositionDTO: Codable, Equatable, Sendable { let baseQty: DecimalString?; let averageExecutionPrice: DecimalString?; let costBasisPrice: DecimalString?; let openedAt: Date?; enum CodingKeys: String, CodingKey { case baseQty = "base_qty", averageExecutionPrice = "average_execution_price", costBasisPrice = "cost_basis_price", openedAt = "opened_at" } }
struct RealOrderDTO: Codable, Equatable, Sendable { let id: String?; let krakenOrderID: String?; let side: String?; let orderType: String?; let status: String?; let requestedQuantity: DecimalString?; let executedQuantity: DecimalString?; let limitPrice: DecimalString?; let averageExecutionPrice: DecimalString?; let requestedQuoteAmount: DecimalString?; let executedQuoteAmount: DecimalString?; let createdAt: Date?; let updatedAt: Date?; enum CodingKeys: String, CodingKey { case id, side, status; case krakenOrderID = "kraken_order_id", orderType = "order_type", requestedQuantity = "requested_quantity", executedQuantity = "executed_quantity", limitPrice = "limit_price", averageExecutionPrice = "average_execution_price", requestedQuoteAmount = "requested_quote_amount", executedQuoteAmount = "executed_quote_amount", createdAt = "created_at", updatedAt = "updated_at" } }
struct RealReconciliationDTO: Codable, Equatable, Sendable { let state: String?; let required: Bool?; let lastCheckedAt: Date?; let lastReconciledAt: Date?; let nextAttemptAt: Date?; let lookupSource: String?; enum CodingKeys: String, CodingKey { case state, required; case lastCheckedAt = "last_checked_at", lastReconciledAt = "last_reconciled_at", nextAttemptAt = "next_attempt_at", lookupSource = "lookup_source" } }
struct RealFeeAwareDTO: Codable, Equatable, Sendable { let executionPrice: DecimalString?; let costBasisPrice: DecimalString?; let buyFeeQuote: DecimalString?; let buyFeeRateEffective: DecimalString?; let buyFeeAsset: String?; let estimatedSellFeeQuote: DecimalString?; let estimatedSellFeeRate: DecimalString?; let estimatedSellFeeSource: String?; let liquidityRole: String?; let liquidityRoleLabel: String?; let breakEvenPrice: DecimalString?; let minimumProfitableExitPrice: DecimalString?; let minimumNetProfitRate: DecimalString?; let estimatedSlippageRate: DecimalString?; let grossCurrentValueQuote: DecimalString?; let unrealizedPnlGrossQuote: DecimalString?; let unrealizedPnlNetEstimatedQuote: DecimalString?; let totalCycleFeesEstimatedQuote: DecimalString?; enum CodingKeys: String, CodingKey { case executionPrice = "execution_price", costBasisPrice = "cost_basis_price", buyFeeQuote = "buy_fee_quote", buyFeeRateEffective = "buy_fee_rate_effective", buyFeeAsset = "buy_fee_asset", estimatedSellFeeQuote = "estimated_sell_fee_quote", estimatedSellFeeRate = "estimated_sell_fee_rate", estimatedSellFeeSource = "estimated_sell_fee_source", liquidityRole = "liquidity_role", liquidityRoleLabel = "liquidity_role_label", breakEvenPrice = "break_even_price", minimumProfitableExitPrice = "minimum_profitable_exit_price", minimumNetProfitRate = "minimum_net_profit_rate", estimatedSlippageRate = "estimated_slippage_rate", grossCurrentValueQuote = "gross_current_value_quote", unrealizedPnlGrossQuote = "unrealized_pnl_gross_quote", unrealizedPnlNetEstimatedQuote = "unrealized_pnl_net_estimated_quote", totalCycleFeesEstimatedQuote = "total_cycle_fees_estimated_quote" } }
