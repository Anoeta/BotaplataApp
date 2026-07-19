import Foundation

struct TimelinePageDTO: Codable, Sendable { let items: [TimelineEventDTO]; let pagination: RealSessionsPaginationDTO }
struct TimelineEventDTO: Codable, Sendable { let id: String; let occurredAt: Date; let type: String?; let severity: String?; let title: String?; let message: String?; let relatedOrderID: String?; let relatedPositionID: String?; let money: TimelineMoneyDTO?; enum CodingKeys: String, CodingKey { case id, type, severity, title, message, money; case occurredAt = "occurred_at", relatedOrderID = "related_order_id", relatedPositionID = "related_position_id" } }
struct TimelineMoneyDTO: Codable, Sendable { let amountQuote: DecimalString?; let currency: String?; enum CodingKeys: String, CodingKey { case amountQuote = "amount_quote", currency } }
struct OrdersPageDTO: Codable, Sendable { let items: [SessionOrderDTO]; let pagination: RealSessionsPaginationDTO }
struct SessionOrderDTO: Codable, Sendable { let id: String; let side: String?; let orderType: String?; let status: String?; let statusLabel: String?; let provider: String?; let exchangeOrderID: String?; let exchangeClientOrderID: String?; let symbol: String?; let requestedQuantity: DecimalString?; let executedQuantity: DecimalString?; let limitPrice: DecimalString?; let averageFillPrice: DecimalString?; let requestedQuoteAmount: DecimalString?; let executedQuoteAmount: DecimalString?; let feesQuote: DecimalString?; let feeRateEffective: DecimalString?; let liquidityRole: String?; let reconciliationState: String?; let createdAt: Date?; let updatedAt: Date?; let filledAt: Date?; let realizedPnlQuote: DecimalString?; let realizedPnlNetQuote: DecimalString?; enum CodingKeys: String, CodingKey { case id, side, status, provider, symbol; case orderType = "order_type", statusLabel = "status_label", exchangeOrderID = "exchange_order_id", exchangeClientOrderID = "exchange_client_order_id", requestedQuantity = "requested_quantity", executedQuantity = "executed_quantity", limitPrice = "limit_price", averageFillPrice = "average_fill_price", requestedQuoteAmount = "requested_quote_amount", executedQuoteAmount = "executed_quote_amount", feesQuote = "fees_quote", feeRateEffective = "fee_rate_effective", liquidityRole = "liquidity_role", reconciliationState = "reconciliation_state", createdAt = "created_at", updatedAt = "updated_at", filledAt = "filled_at", realizedPnlQuote = "realized_pnl_quote", realizedPnlNetQuote = "realized_pnl_net_quote" } }
struct DecisionsPageDTO: Codable, Sendable { let items: [SessionDecisionDTO]; let pagination: RealSessionsPaginationDTO }
struct SessionDecisionDTO: Codable, Sendable { let id: String; let createdAt: Date; let decision: String?; let decisionLabel: String?; let score: DecimalString?; let scoreMin: DecimalString?; let price: DecimalString?; let controller: String?; let blockers: [String]?; let buyConditions: [String]?; let sellConditions: [String]?; let advice: String?; let summaryTitle: String?; let summaryMessage: String?; enum CodingKeys: String, CodingKey { case id, decision, score, price, controller, blockers, advice; case createdAt = "created_at", decisionLabel = "decision_label", scoreMin = "score_min", buyConditions = "buy_conditions", sellConditions = "sell_conditions", summaryTitle = "summary_title", summaryMessage = "summary_message" }
    init(from decoder: Decoder) throws { let c = try decoder.container(keyedBy: CodingKeys.self); id = try c.decode(String.self, forKey: .id); createdAt = try c.decode(Date.self, forKey: .createdAt); decision = try c.decodeIfPresent(String.self, forKey: .decision); decisionLabel = try c.decodeIfPresent(String.self, forKey: .decisionLabel); score = try c.decodeIfPresent(DecimalString.self, forKey: .score); scoreMin = try c.decodeIfPresent(DecimalString.self, forKey: .scoreMin); price = try c.decodeIfPresent(DecimalString.self, forKey: .price); controller = try c.decodeIfPresent(String.self, forKey: .controller); blockers = try c.decodeLossyStringArrayIfPresent(forKey: .blockers); buyConditions = try c.decodeLossyStringArrayIfPresent(forKey: .buyConditions); sellConditions = try c.decodeLossyStringArrayIfPresent(forKey: .sellConditions); advice = try c.decodeIfPresent(String.self, forKey: .advice); summaryTitle = try c.decodeIfPresent(String.self, forKey: .summaryTitle); summaryMessage = try c.decodeIfPresent(String.self, forKey: .summaryMessage) }
}

extension KeyedDecodingContainer {
    func decodeLossyStringArrayIfPresent(forKey key: Key) throws -> [String]? {
        guard contains(key) else { return nil }
        return try decodeLossyStringArray(forKey: key)
    }

    func decodeLossyStringArray(forKey key: Key) throws -> [String] {
        var container = try nestedUnkeyedContainer(forKey: key)
        var values: [String] = []
        while !container.isAtEnd {
            if try container.decodeNil() { continue }
            let value = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { values.append(value) }
        }
        return values
    }
}
struct SessionChartDTO: Codable, Sendable { let sessionID: String; let symbol: String?; let displaySymbol: String?; let quoteAsset: String?; let timeframe: String?; let points: [ChartPointDTO]; let markers: [ChartMarkerDTO]; let levels: ChartLevelsDTO?; enum CodingKeys: String, CodingKey { case symbol, timeframe, points, markers, levels; case sessionID = "session_id", displaySymbol = "display_symbol", quoteAsset = "quote_asset" } }
struct ChartPointDTO: Codable, Sendable { let timestamp: Date; let price: DecimalString? }
struct ChartMarkerDTO: Codable, Sendable { let id: String; let timestamp: Date; let type: String?; let label: String?; let price: DecimalString?; let quantity: DecimalString?; let quoteAmount: DecimalString?; enum CodingKeys: String, CodingKey { case id, timestamp, type, label, price, quantity; case quoteAmount = "quote_amount" } }
struct ChartLevelsDTO: Codable, Sendable { let executionPrice: DecimalString?; let costBasisPrice: DecimalString?; let breakEvenPrice: DecimalString?; let minimumProfitableExitPrice: DecimalString?; enum CodingKeys: String, CodingKey { case executionPrice = "execution_price", costBasisPrice = "cost_basis_price", breakEvenPrice = "break_even_price", minimumProfitableExitPrice = "minimum_profitable_exit_price" } }
