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

struct FlexibleStringValueDTO: Codable, Equatable, Sendable {
    let value: String?

    init(_ value: String?) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = nil; return }
        if let stringValue = try? c.decode(String.self) { value = stringValue; return }
        if let intValue = try? c.decode(Int.self) { value = String(intValue); return }
        if let doubleValue = try? c.decode(Double.self) { value = NSDecimalNumber(value: doubleValue).stringValue; return }
        if let boolValue = try? c.decode(Bool.self) { value = String(boolValue); return }
        throw DecodingError.typeMismatch(String.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected string, number, boolean, or null"))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let value {
            try c.encode(value)
        } else {
            try c.encodeNil()
        }
    }
}

struct RealActiveSnapshotDTO: Codable, Equatable, Sendable {
    let generatedAt: Date?
    let dataSource: String?
    let executionMode: String?
    let activeSessionCount: Int?
    let activeSession: RealSessionDetailDTO?
    enum CodingKeys: String, CodingKey { case generatedAt = "generated_at", dataSource = "data_source", executionMode = "execution_mode", activeSessionCount = "active_session_count", activeSession = "active_session" }
}

struct RealMonitoringDTO: Codable, Equatable, Sendable { let health: String?; let lastSuccessAt: Date?; let lastErrorAt: Date?; let consecutiveErrors: Int?; enum CodingKeys: String, CodingKey { case health; case lastSuccessAt = "last_success_at", lastErrorAt = "last_error_at", consecutiveErrors = "consecutive_errors" } }
struct RealFreshnessDTO: Codable, Equatable, Sendable { let snapshotGeneratedAt: Date?; let updatedAt: Date?; let ageSeconds: Int?; let status: String?; enum CodingKeys: String, CodingKey { case status; case snapshotGeneratedAt = "snapshot_generated_at", updatedAt = "updated_at", ageSeconds = "age_seconds" } }
struct RealMarketDTO: Codable, Equatable, Sendable { let currentPrice: DecimalString?; let quoteAsset: String?; let source: String?; let observedAt: Date?; let updatedAt: Date?; enum CodingKeys: String, CodingKey { case source; case currentPrice = "current_price", quoteAsset = "quote_asset", observedAt = "observed_at", updatedAt = "updated_at" } }
struct RealDecisionDTO: Codable, Equatable, Sendable { let decision: String?; let title: String?; let detail: String?; let score: DecimalString?; let scoreMin: DecimalString?; let favorableConditions: Int?; let requiredConditions: Int?; let controller: String?; let blockers: [String]; let buyConditions: [RealStrategyConditionDTO]; let sellConditions: [RealStrategyConditionDTO]; let advice: String?; let price: DecimalString?; let createdAt: Date?; enum CodingKeys: String, CodingKey { case decision, title, detail, score, controller, blockers, advice, price; case scoreMin = "score_min", favorableConditions = "favorable_conditions", requiredConditions = "required_conditions", buyConditions = "buy_conditions", sellConditions = "sell_conditions", createdAt = "created_at" }
    init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); decision = try c.decodeIfPresent(String.self, forKey: .decision); title = try c.decodeIfPresent(String.self, forKey: .title); detail = try c.decodeIfPresent(String.self, forKey: .detail); score = try c.decodeIfPresent(DecimalString.self, forKey: .score); scoreMin = try c.decodeIfPresent(DecimalString.self, forKey: .scoreMin); favorableConditions = try c.decodeIfPresent(Int.self, forKey: .favorableConditions); requiredConditions = try c.decodeIfPresent(Int.self, forKey: .requiredConditions); controller = try c.decodeIfPresent(String.self, forKey: .controller); blockers = try c.decodeIfPresent([String].self, forKey: .blockers) ?? []; buyConditions = try c.decodeIfPresent([RealStrategyConditionDTO].self, forKey: .buyConditions) ?? []; sellConditions = try c.decodeIfPresent([RealStrategyConditionDTO].self, forKey: .sellConditions) ?? []; advice = try c.decodeIfPresent(String.self, forKey: .advice); price = try c.decodeIfPresent(DecimalString.self, forKey: .price); createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) } }
struct RealStrategyConditionDTO: Codable, Equatable, Sendable {
    let key: String?
    let label: String?
    let state: String?
    let value: String?
    let threshold: String?
    let detail: String?

    enum CodingKeys: String, CodingKey { case key, code, label, state, status, value, threshold, detail }

    init(key: String?, label: String?, state: String?, value: String?, threshold: String?, detail: String?) {
        self.key = key
        self.label = label
        self.state = state
        self.value = value
        self.threshold = threshold
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decodeIfPresent(String.self, forKey: .key) ?? c.decodeIfPresent(String.self, forKey: .code)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? c.decodeIfPresent(String.self, forKey: .status)
        value = try c.decodeIfPresent(FlexibleStringValueDTO.self, forKey: .value)?.value
        threshold = try c.decodeIfPresent(FlexibleStringValueDTO.self, forKey: .threshold)?.value
        detail = try c.decodeIfPresent(String.self, forKey: .detail)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(key, forKey: .key)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(state, forKey: .state)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encodeIfPresent(threshold, forKey: .threshold)
        try c.encodeIfPresent(detail, forKey: .detail)
    }
}
struct RealPositionDTO: Codable, Equatable, Sendable { let id: String?; let status: String?; let side: String?; let symbol: String?; let baseQty: DecimalString?; let entryPrice: DecimalString?; let averageExecutionPrice: DecimalString?; let costBasisPrice: DecimalString?; let currentPrice: DecimalString?; let estimatedValueQuote: DecimalString?; let unrealizedPnlQuote: DecimalString?; let openedAt: Date?; let origin: String?; let reconciliationPending: Bool?; enum CodingKeys: String, CodingKey { case id, status, side, symbol, origin; case baseQty = "base_qty", entryPrice = "entry_price", averageExecutionPrice = "average_execution_price", costBasisPrice = "cost_basis_price", currentPrice = "current_price", estimatedValueQuote = "estimated_value_quote", unrealizedPnlQuote = "unrealized_pnl_quote", openedAt = "opened_at", reconciliationPending = "reconciliation_pending" } }
struct RealOrderDTO: Codable, Equatable, Sendable { let id: String?; let exchangeOrderID: String?; let krakenOrderID: String?; let statusLabel: String?; let provider: String?; let exchangeOrderIDLabel: String?; let side: String?; let orderType: String?; let status: String?; let requestedQuantity: DecimalString?; let executedQuantity: DecimalString?; let limitPrice: DecimalString?; let averageFillPrice: DecimalString?; let averageExecutionPrice: DecimalString?; let requestedQuoteAmount: DecimalString?; let executedQuoteAmount: DecimalString?; let createdAt: Date?; let updatedAt: Date?; enum CodingKeys: String, CodingKey { case id, side, status, provider; case exchangeOrderID = "exchange_order_id", krakenOrderID = "kraken_order_id", statusLabel = "status_label", exchangeOrderIDLabel = "exchange_order_id_label", orderType = "order_type", requestedQuantity = "requested_quantity", executedQuantity = "executed_quantity", limitPrice = "limit_price", averageFillPrice = "average_fill_price", averageExecutionPrice = "average_execution_price", requestedQuoteAmount = "requested_quote_amount", executedQuoteAmount = "executed_quote_amount", createdAt = "created_at", updatedAt = "updated_at" } }
struct RealReconciliationDTO: Codable, Equatable, Sendable { let state: String?; let required: Bool?; let orderID: String?; let lastCheckedAt: Date?; let lastReconciledAt: Date?; let nextAttemptAt: Date?; let lookupSource: String?; enum CodingKeys: String, CodingKey { case state, required; case orderID = "order_id"; case lastCheckedAt = "last_checked_at", lastReconciledAt = "last_reconciled_at", nextAttemptAt = "next_attempt_at", lookupSource = "lookup_source" } }
struct RealFeeAwareDTO: Codable, Equatable, Sendable { let executionPrice: DecimalString?; let costBasisPrice: DecimalString?; let buyFeeQuote: DecimalString?; let buyFeeRateEffective: DecimalString?; let buyFeeAsset: String?; let estimatedSellFeeQuote: DecimalString?; let estimatedSellFeeRate: DecimalString?; let estimatedSellFeeSource: String?; let liquidityRole: String?; let liquidityRoleLabel: String?; let breakEvenPrice: DecimalString?; let minimumProfitableExitPrice: DecimalString?; let minimumNetProfitRate: DecimalString?; let estimatedSlippageRate: DecimalString?; let grossCurrentValueQuote: DecimalString?; let unrealizedPnlGrossQuote: DecimalString?; let unrealizedPnlNetEstimatedQuote: DecimalString?; let totalCycleFeesEstimatedQuote: DecimalString?; enum CodingKeys: String, CodingKey { case executionPrice = "execution_price", costBasisPrice = "cost_basis_price", buyFeeQuote = "buy_fee_quote", buyFeeRateEffective = "buy_fee_rate_effective", buyFeeAsset = "buy_fee_asset", estimatedSellFeeQuote = "estimated_sell_fee_quote", estimatedSellFeeRate = "estimated_sell_fee_rate", estimatedSellFeeSource = "estimated_sell_fee_source", liquidityRole = "liquidity_role", liquidityRoleLabel = "liquidity_role_label", breakEvenPrice = "break_even_price", minimumProfitableExitPrice = "minimum_profitable_exit_price", minimumNetProfitRate = "minimum_net_profit_rate", estimatedSlippageRate = "estimated_slippage_rate", grossCurrentValueQuote = "gross_current_value_quote", unrealizedPnlGrossQuote = "unrealized_pnl_gross_quote", unrealizedPnlNetEstimatedQuote = "unrealized_pnl_net_estimated_quote", totalCycleFeesEstimatedQuote = "total_cycle_fees_estimated_quote" } }

