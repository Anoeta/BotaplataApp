import Foundation

enum StrategyDecisionCode: String, Codable, Sendable { case wait, watch, buyReady = "buy_ready", buySubmitted = "buy_submitted", buyConfirmed = "buy_confirmed", positionOpen = "position_open", sellReady = "sell_ready", sellSubmitted = "sell_submitted", sellConfirmed = "sell_confirmed", safetyBlocked = "safety_blocked", historyPreparing = "history_preparing", dataStale = "data_stale", maintenance, unknown; init(backend: String?) { self = StrategyDecisionCode(rawValue: backend ?? "") ?? .unknown } }
enum StrategyConditionStatus: String, Codable, Sendable { case favorable, unfavorable, neutral, unavailable, blocked, unknown; init(backend: String?) { self = StrategyConditionStatus(rawValue: backend ?? "") ?? .unknown } }
enum StrategyBlockerSeverity: String, Codable, Sendable { case info, warning, blocking, critical, unknown; init(backend: String?) { self = StrategyBlockerSeverity(rawValue: backend ?? "") ?? .unknown } }
enum StrategyRegimeCode: String, Codable, Sendable { case range, trendUp = "trend_up", trendDown = "trend_down", volatile, uncertain, unavailable, unknown; init(backend: String?) { self = StrategyRegimeCode(rawValue: backend ?? "") ?? .unknown } }
enum StrategyMomentumCode: String, Codable, Sendable { case bullish, bearish, neutral, weakening, strengthening, unavailable, unknown; init(backend: String?) { self = StrategyMomentumCode(rawValue: backend ?? "") ?? .unknown } }

struct StrategyExplanation: Equatable, Sendable { let sessionID: String; let strategy: StrategyIdentity; let decision: StrategyExplanationDecision; let score: StrategyScore?; let analysis: StrategyAnalysisContext; let market: StrategyMarketContext; let conditions: [StrategyCondition]; let blockers: [StrategyBlocker]; let indicators: StrategyIndicatorSet; let positionProtection: StrategyPositionProtection?; let warnings: [StrategyExplanationWarning]; let meta: StrategyExplanationMeta }
struct StrategyIdentity: Equatable, Sendable { let code: String; let name: String; let version: String? }
struct StrategyExplanationDecision: Equatable, Sendable { let rawValue: String; let code: StrategyDecisionCode; let label: String; let summary: String; let technicalDetail: String?; let status: String?; let decidedAt: Date? }
struct StrategyScore: Equatable, Sendable { let currentRaw: String?; let current: Int?; let requiredRaw: String?; let required: Int?; let maximumRaw: String?; let maximum: Int?; let favorableConditions: Int?; let totalConditions: Int?; let summary: String? }
struct StrategyAnalysisContext: Equatable, Sendable { let timeframe: String?; let candleCloseTime: Date?; let calculatedAt: Date?; let nextRecalculationAt: Date?; let freshness: StrategyFreshness; let summary: String?; let technicalDetail: String? }
struct StrategyFreshness: Equatable, Sendable { let status: String; let label: String?; let summary: String?; let isStale: Bool }
struct StrategyMarketContext: Equatable, Sendable { let regime: StrategyMarketRegime; let momentum: StrategyMarketMomentum; let summary: String? }
struct StrategyMarketRegime: Equatable, Sendable { let rawValue: String; let code: StrategyRegimeCode; let label: String; let summary: String? }
struct StrategyMarketMomentum: Equatable, Sendable { let rawValue: String; let code: StrategyMomentumCode; let label: String; let summary: String? }
struct StrategyCondition: Identifiable, Equatable, Sendable { let id: String; let code: String; let label: String; let status: StrategyConditionStatus; let statusRaw: String; let summary: String; let valueRaw: String?; let thresholdRaw: String?; let technicalDetail: String? }
struct StrategyBlocker: Identifiable, Equatable, Sendable { let id: String; let code: String; let label: String; let summary: String; let severity: StrategyBlockerSeverity; let severityRaw: String; let recoverable: Bool?; let technicalDetail: String? }
struct StrategyIndicator: Identifiable, Equatable, Sendable { let id: String; let name: String; let valueRaw: String?; let status: String?; let help: String; let technicalDetail: String? }
struct StrategyIndicatorSet: Equatable, Sendable {
  let indicators: [StrategyIndicator]
  var rsi: Decimal? { decimalValue(for: "rsi") }
  func value(for id: String) -> StrategyIndicator? { indicators.first { $0.id == id } }
  private func decimalValue(for id: String) -> Decimal? {
    guard let raw = value(for: id)?.valueRaw?.replacingOccurrences(of: ",", with: ".") else { return nil }
    return Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX"))
  }
}
struct StrategyPositionProtection: Equatable, Sendable { let summary: String; let entryPriceRaw: String?; let currentPriceRaw: String?; let unrealizedPnLRaw: String?; let breakEvenPriceRaw: String?; let minimumProfitablePriceRaw: String?; let trailingActive: Bool?; let trailingStopRaw: String?; let sellConditions: [String]; let technicalDetail: String? }
struct StrategyExplanationWarning: Identifiable, Equatable, Sendable { let id: String; let severity: StrategyBlockerSeverity; let title: String; let message: String }
struct StrategyExplanationMeta: Equatable, Sendable { let requestID: String?; let serverTime: Date?; let generatedAt: Date?; let source: String? }

struct StrategyRSIPresentation: Equatable, Sendable {
  let rsiDisplayValue: String
  let rsiStatusText: String
  let isRSIUnavailable: Bool

  init(explanation: StrategyExplanation) {
    let condition = explanation.conditions.first { $0.code == "rsi" }
    if let rsi = explanation.indicators.rsi {
      rsiDisplayValue = Self.format(rsi)
      rsiStatusText = condition?.status == .favorable ? "Favorable" : "À confirmer"
      isRSIUnavailable = false
    } else {
      rsiDisplayValue = "RSI indisponible"
      rsiStatusText = "La dernière analyse ne contient pas encore cette valeur."
      isRSIUnavailable = true
    }
  }

  private static func format(_ value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.minimumFractionDigits = 1
    formatter.maximumFractionDigits = 1
    return formatter.string(from: value as NSDecimalNumber) ?? NSDecimalNumber(decimal: value).stringValue
  }
}
