import Foundation

struct RealStrategyExplanationDTO: Decodable, Sendable {
  let data: RealStrategyExplanationDataDTO
  let meta: StrategyExplanationMetaDTO
}
struct RealStrategyExplanationDataDTO: Decodable, Sendable {
  let sessionID: String
  let strategy: StrategyIdentityDTO
  let decision: StrategyExplanationDecisionDTO
  let score: StrategyExplanationScoreDTO?
  let analysis: StrategyExplanationAnalysisDTO
  let market: StrategyExplanationMarketDTO
  let conditions: [StrategyExplanationConditionDTO]
  let blockers: [StrategyExplanationBlockerDTO]
  let indicators: StrategyExplanationIndicatorsDTO
  let positionProtection: StrategyExplanationPositionProtectionDTO?
  let warnings: [StrategyExplanationWarningDTO]
  enum CodingKeys: String, CodingKey {
    case strategy, decision, score, analysis, market, conditions, blockers, indicators, warnings
    case sessionID = "session_id"
    case positionProtection = "position_protection"
  }
}
struct StrategyIdentityDTO: Decodable, Sendable {
  let code: String
  let name: String
  let version: String?
}
struct StrategyExplanationDecisionDTO: Decodable, Sendable {
  let code: String
  let label: String
  let summary: String
  let technicalDetail: String?
  let status: String?
  let decidedAt: Date?
  enum CodingKeys: String, CodingKey {
    case code, label, summary, status
    case technicalDetail = "technical_detail"
    case decidedAt = "decided_at"
  }
}
struct FlexibleIntDTO: Decodable, Sendable {
  let value: Int

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    if let intValue = try? container.decode(Int.self) {
      value = intValue
      return
    }

    if let doubleValue = try? container.decode(Double.self), doubleValue.isFinite,
      doubleValue.rounded(.towardZero) == doubleValue, doubleValue >= Double(Int.min),
      doubleValue <= Double(Int.max)
    {
      value = Int(doubleValue)
      return
    }

    if let stringValue = try? container.decode(String.self), let intValue = Int(stringValue) {
      value = intValue
      return
    }

    throw DecodingError.typeMismatch(
      Int.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "Expected an integer score encoded as a JSON number or numeric string")
    )
  }
}

struct StrategyExplanationScoreDTO: Decodable, Sendable {
  let current: FlexibleIntDTO?
  let required: FlexibleIntDTO?
  let maximum: FlexibleIntDTO?
  let favorableConditions: FlexibleIntDTO?
  let totalConditions: FlexibleIntDTO?
  let summary: String?
  enum CodingKeys: String, CodingKey {
    case current, required, maximum, summary
    case favorableConditions = "favorable_conditions"
    case totalConditions = "total_conditions"
  }
}
struct StrategyExplanationAnalysisDTO: Decodable, Sendable {
  let timeframe: String?
  let candleCloseTime: Date?
  let calculatedAt: Date?
  let nextRecalculationAt: Date?
  let freshness: StrategyExplanationFreshnessDTO?
  let summary: String?
  let technicalDetail: String?
  enum CodingKeys: String, CodingKey {
    case timeframe, freshness, summary
    case candleCloseTime = "candle_close_time"
    case calculatedAt = "calculated_at"
    case nextRecalculationAt = "next_recalculation_at"
    case technicalDetail = "technical_detail"
  }
}
struct StrategyExplanationFreshnessDTO: Decodable, Sendable {
  let status: String?
  let label: String?
  let summary: String?
  let isStale: Bool?
  enum CodingKeys: String, CodingKey {
    case status, label, summary
    case isStale = "is_stale"
  }
}
struct StrategyExplanationMarketDTO: Decodable, Sendable {
  let regime: StrategyExplanationRegimeDTO
  let momentum: StrategyExplanationMomentumDTO
  let summary: String?
}
struct StrategyExplanationRegimeDTO: Decodable, Sendable {
  let code: String
  let label: String
  let summary: String?
}
struct StrategyExplanationMomentumDTO: Decodable, Sendable {
  let code: String
  let label: String
  let summary: String?
}
struct StrategyExplanationConditionDTO: Decodable, Sendable {
  let code: String
  let label: String
  let status: String
  let value: String?
  let threshold: String?
  let summary: String?
  let technicalDetail: String?
  let importance: String?
  enum CodingKeys: String, CodingKey {
    case id, code, label, status, value, threshold, summary, importance
    case technicalDetail = "technical_detail"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    code = try c.decodeIfPresent(String.self, forKey: .code) ?? c.decode(String.self, forKey: .id)
    label = try c.decode(String.self, forKey: .label)
    status = try c.decode(String.self, forKey: .status)
    value = try c.decodeIfPresent(String.self, forKey: .value)
    threshold = try c.decodeIfPresent(String.self, forKey: .threshold)
    summary = try c.decodeIfPresent(String.self, forKey: .summary)
    technicalDetail = try c.decodeIfPresent(String.self, forKey: .technicalDetail)
    importance = try c.decodeIfPresent(String.self, forKey: .importance)
  }
}
struct StrategyExplanationBlockerDTO: Decodable, Sendable {
  let code: String
  let label: String
  let severity: String
  let summary: String?
  let recoverable: Bool?
  let technicalDetail: String?
  enum CodingKeys: String, CodingKey {
    case id, code, label, severity, summary, recoverable
    case technicalDetail = "technical_detail"
    case isRecoverable = "is_recoverable"
  }
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    code = try c.decodeIfPresent(String.self, forKey: .code) ?? c.decode(String.self, forKey: .id)
    label = try c.decode(String.self, forKey: .label)
    severity = try c.decode(String.self, forKey: .severity)
    summary = try c.decodeIfPresent(String.self, forKey: .summary)
    recoverable =
      try c.decodeIfPresent(Bool.self, forKey: .isRecoverable)
      ?? c.decodeIfPresent(Bool.self, forKey: .recoverable)
    technicalDetail = try c.decodeIfPresent(String.self, forKey: .technicalDetail)
  }
}
struct StrategyExplanationIndicatorsDTO: Decodable, Sendable {
  let rsi: StrategyExplanationIndicatorDTO?
  let adx: StrategyExplanationIndicatorDTO?
  let atr: StrategyExplanationIndicatorDTO?
  let vwap: StrategyExplanationIndicatorDTO?
  let ema200: StrategyExplanationIndicatorDTO?
  let ema200Slope: StrategyExplanationIndicatorDTO?
  let bollinger: StrategyExplanationIndicatorDTO?
  enum CodingKeys: String, CodingKey {
    case rsi, adx, atr, vwap, bollinger
    case ema200 = "ema200"
    case ema200Slope = "ema200_slope"
  }
}
struct StrategyExplanationIndicatorDTO: Decodable, Sendable {
  let value: String?
  let label: String?
  let status: String?
  let summary: String?
  let technicalDetail: String?
  enum CodingKeys: String, CodingKey {
    case value, label, status, summary
    case technicalDetail = "technical_detail"
  }
}
struct StrategyExplanationPositionProtectionDTO: Decodable, Sendable {
  let summary: String
  let entryPrice: String?
  let currentPrice: String?
  let unrealizedPnL: String?
  let breakEvenPrice: String?
  let minimumProfitablePrice: String?
  let trailingActive: Bool?
  let trailingStop: String?
  let sellConditions: [String]
  let technicalDetail: String?
  enum CodingKeys: String, CodingKey {
    case summary
    case entryPrice = "entry_price"
    case currentPrice = "current_price"
    case unrealizedPnL = "unrealized_pnl"
    case breakEvenPrice = "break_even_price"
    case minimumProfitablePrice = "minimum_profitable_price"
    case trailingActive = "trailing_active"
    case trailingStop = "trailing_stop"
    case sellConditions = "sell_conditions"
    case technicalDetail = "technical_detail"
  }
}
struct StrategyExplanationWarningDTO: Decodable, Sendable {
  let id: String
  let severity: String
  let title: String
  let message: String
}
struct StrategyExplanationMetaDTO: Decodable, Sendable {
  let requestID: String?
  let serverTime: Date?
  let generatedAt: Date?
  let dataSource: String?
  enum CodingKeys: String, CodingKey {
    case requestID = "request_id"
    case serverTime = "server_time"
    case generatedAt = "generated_at"
    case dataSource = "data_source"
  }
}
