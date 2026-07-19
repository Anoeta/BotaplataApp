import Foundation
import OSLog
import Observation

extension RealStrategyExplanationDTO {
  func mapped() -> StrategyExplanation { data.mapped(metaDTO: meta) }
}

extension RealStrategyExplanationDataDTO {
  func mapped(metaDTO: StrategyExplanationMetaDTO) -> StrategyExplanation {
    let strategyModel: StrategyIdentity = mapStrategy()
    let decisionModel: StrategyExplanationDecision = mapDecision()
    let scoreModel: StrategyScore? = mapScore()
    let analysisModel: StrategyAnalysisContext = mapAnalysis()
    let marketModel: StrategyMarketContext = mapMarket()
    let conditionModels: [StrategyCondition] = mapConditions()
    let blockerModels: [StrategyBlocker] = mapBlockers()
    let conditionNullValues = conditionModels.filter { $0.valueRaw == nil }.count
    let indicatorModels: StrategyIndicatorSet = mapIndicators()
    let positionModel: StrategyPositionProtection? = mapPositionProtection()
    let warningModels: [StrategyExplanationWarning] = mapWarnings()
    let metaModel: StrategyExplanationMeta = metaDTO.mapped()

    let mapped = StrategyExplanation(
      sessionID: sessionID,
      strategy: strategyModel,
      decision: decisionModel,
      score: scoreModel,
      analysis: analysisModel,
      market: marketModel,
      conditions: conditionModels,
      blockers: blockerModels,
      indicators: indicatorModels,
      positionProtection: positionModel,
      warnings: warningModels,
      meta: metaModel
    )

    BotaplataLog.strategyExplanation.info(
      "StrategyExplanationMapper decision=\(mapped.decision.rawValue, privacy: .public) score=\(mapped.score?.currentRaw ?? "nil", privacy: .public)/\(mapped.score?.requiredRaw ?? "nil", privacy: .public) conditions=\(mapped.conditions.count, privacy: .public) blockers=\(mapped.blockers.count, privacy: .public)"
    )
    BotaplataLog.strategyExplanation.debug(
      "StrategyExplanationMapper conditions=\(mapped.conditions.count, privacy: .public) conditionNullValues=\(conditionNullValues, privacy: .public)"
    )
    return mapped
  }

  private func mapStrategy() -> StrategyIdentity {
    StrategyIdentity(
      code: strategy.code,
      name: strategy.name,
      version: strategy.version
    )
  }

  private func mapDecision() -> StrategyExplanationDecision {
    let decisionCode = StrategyDecisionCode(backend: decision.code)

    return StrategyExplanationDecision(
      rawValue: decision.code,
      code: decisionCode,
      label: decision.label,
      summary: decision.summary,
      technicalDetail: decision.technicalDetail,
      status: decision.status,
      decidedAt: decision.decidedAt
    )
  }

  private func mapScore() -> StrategyScore? {
    guard let score else { return nil }

    return StrategyScore(
      currentRaw: score.current.map { String($0.value) },
      current: score.current?.value,
      requiredRaw: score.required.map { String($0.value) },
      required: score.required?.value,
      maximumRaw: score.maximum.map { String($0.value) },
      maximum: score.maximum?.value,
      favorableConditions: score.favorableConditions?.value,
      totalConditions: score.totalConditions?.value,
      summary: score.summary
    )
  }

  private func mapAnalysis() -> StrategyAnalysisContext {
    let freshnessModel: StrategyFreshness = analysis.freshness.mapped()

    return StrategyAnalysisContext(
      timeframe: analysis.timeframe,
      candleCloseTime: analysis.candleCloseTime,
      calculatedAt: analysis.calculatedAt,
      nextRecalculationAt: analysis.nextRecalculationAt,
      freshness: freshnessModel,
      summary: analysis.summary,
      technicalDetail: analysis.technicalDetail
    )
  }

  private func mapMarket() -> StrategyMarketContext {
    let regimeModel: StrategyMarketRegime = market.regime.mapped()
    let momentumModel: StrategyMarketMomentum = market.momentum.mapped()

    return StrategyMarketContext(
      regime: regimeModel,
      momentum: momentumModel,
      summary: market.summary
    )
  }

  private func mapConditions() -> [StrategyCondition] {
    conditions.map { $0.mapped() }
  }

  private func mapBlockers() -> [StrategyBlocker] {
    blockers.map { $0.mapped() }
  }

  private func mapIndicators() -> StrategyIndicatorSet {
    let rsiCondition = conditions.first { $0.code == "rsi" }
    let rsiSource: String
    if indicators.rsi?.value != nil {
      rsiSource = "indicators"
    } else if rsiCondition?.value != nil {
      rsiSource = "condition"
    } else {
      rsiSource = "none"
    }
    BotaplataLog.strategyExplanation.debug(
      "StrategyExplanationMapper indicators rsiPresent=\(indicators.rsi?.value != nil, privacy: .public) adxPresent=\(indicators.adx?.value != nil, privacy: .public) atrPresent=\(indicators.atr?.value != nil, privacy: .public)"
    )
    BotaplataLog.strategyExplanation.debug("StrategyExplanationMapper rsiSource=\(rsiSource, privacy: .public)")
    BotaplataLog.strategyExplanation.debug("StrategyExplanationMapper rsiConditionValuePresent=\(rsiCondition?.value != nil, privacy: .public)")
    return indicators.mapped(rsiCondition: rsiCondition)
  }

  private func mapPositionProtection() -> StrategyPositionProtection? {
    positionProtection?.mapped()
  }

  private func mapWarnings() -> [StrategyExplanationWarning] {
    warnings.map { $0.mapped() }
  }

}

extension Optional where Wrapped == StrategyExplanationFreshnessDTO {
  fileprivate func mapped() -> StrategyFreshness {
    let dto = self
    let statusValue: String = dto?.status ?? "unknown"

    let isStaleValue: Bool
    if let explicit = dto?.isStale {
      isStaleValue = explicit
    } else {
      isStaleValue = (dto?.status == "stale")
    }

    return StrategyFreshness(
      status: statusValue,
      label: dto?.label,
      summary: dto?.summary,
      isStale: isStaleValue
    )
  }
}

extension StrategyExplanationRegimeDTO {
  fileprivate func mapped() -> StrategyMarketRegime {
    StrategyMarketRegime(
      rawValue: code,
      code: StrategyRegimeCode(backend: code),
      label: label,
      summary: summary
    )
  }
}

extension StrategyExplanationMomentumDTO {
  fileprivate func mapped() -> StrategyMarketMomentum {
    StrategyMarketMomentum(
      rawValue: code,
      code: StrategyMomentumCode(backend: code),
      label: label,
      summary: summary
    )
  }
}

extension StrategyExplanationConditionDTO {
  fileprivate func mapped() -> StrategyCondition {
    let statusModel = StrategyConditionStatus(backend: status)

    return StrategyCondition(
      id: code,
      code: code,
      label: label,
      status: statusModel,
      statusRaw: status,
      summary: summary ?? label,
      valueRaw: value,
      thresholdRaw: threshold,
      technicalDetail: technicalDetail
    )
  }
}

extension StrategyExplanationBlockerDTO {
  fileprivate func mapped() -> StrategyBlocker {
    let severityModel = StrategyBlockerSeverity(backend: severity)

    return StrategyBlocker(
      id: code,
      code: code,
      label: label,
      summary: summary ?? label,
      severity: severityModel,
      severityRaw: severity,
      recoverable: recoverable,
      technicalDetail: technicalDetail
    )
  }
}

extension StrategyExplanationIndicatorsDTO {
  fileprivate func mapped(rsiCondition: StrategyExplanationConditionDTO? = nil) -> StrategyIndicatorSet {
    var result: [StrategyIndicator] = []

    if let rsi {
      result.append(rsi.mappedAsRSI())
    } else if let rsiCondition, let value = rsiCondition.value {
      result.append(StrategyExplanationIndicatorDTO(value: value, label: rsiCondition.label, status: rsiCondition.status, summary: rsiCondition.summary, technicalDetail: rsiCondition.technicalDetail).mappedAsRSI())
    }

    if let adx {
      result.append(adx.mappedAsADX())
    }

    if let atr {
      result.append(atr.mappedAsATR())
    }

    if let vwap {
      result.append(vwap.mappedAsVWAP())
    }

    if let ema200 {
      result.append(ema200.mappedAsEMA200())
    }

    if let ema200Slope {
      result.append(ema200Slope.mappedAsEMA200Slope())
    }

    if let bollinger {
      result.append(bollinger.mappedAsBollinger())
    }

    return StrategyIndicatorSet(indicators: result)
  }
}

extension StrategyExplanationIndicatorDTO {
  fileprivate func mappedAsRSI() -> StrategyIndicator {
    mapped(
      id: "rsi",
      fallbackName: "RSI",
      fallbackHelp: "Le RSI mesure si le marché a beaucoup monté ou baissé récemment."
    )
  }

  fileprivate func mappedAsADX() -> StrategyIndicator {
    mapped(
      id: "adx",
      fallbackName: "ADX",
      fallbackHelp: "L’ADX indique si le marché suit une tendance forte ou évolue plus librement."
    )
  }

  fileprivate func mappedAsATR() -> StrategyIndicator {
    mapped(
      id: "atr",
      fallbackName: "ATR",
      fallbackHelp: "L’ATR mesure l’amplitude habituelle des mouvements de prix."
    )
  }

  fileprivate func mappedAsVWAP() -> StrategyIndicator {
    mapped(
      id: "vwap",
      fallbackName: "VWAP",
      fallbackHelp: "Le VWAP représente le prix moyen pondéré par les volumes."
    )
  }

  fileprivate func mappedAsEMA200() -> StrategyIndicator {
    mapped(
      id: "ema200",
      fallbackName: "EMA200",
      fallbackHelp: "L’EMA200 donne une vision de la tendance de fond."
    )
  }

  fileprivate func mappedAsEMA200Slope() -> StrategyIndicator {
    mapped(
      id: "ema200_slope",
      fallbackName: "Pente EMA200",
      fallbackHelp: "La pente EMA200 décrit la tendance de fond fournie par le serveur."
    )
  }

  fileprivate func mappedAsBollinger() -> StrategyIndicator {
    mapped(
      id: "bollinger",
      fallbackName: "Bollinger",
      fallbackHelp:
        "Les bandes de Bollinger aident à situer le prix dans sa zone récente d’évolution."
    )
  }

  private func mapped(
    id: String,
    fallbackName: String,
    fallbackHelp: String
  ) -> StrategyIndicator {
    let nameValue: String = label ?? fallbackName
    let helpValue: String = summary ?? fallbackHelp

    return StrategyIndicator(
      id: id,
      name: nameValue,
      valueRaw: value,
      status: status,
      help: helpValue,
      technicalDetail: technicalDetail
    )
  }
}

extension StrategyExplanationPositionProtectionDTO {
  fileprivate func mapped() -> StrategyPositionProtection {
    StrategyPositionProtection(
      summary: summary,
      entryPriceRaw: entryPrice,
      currentPriceRaw: currentPrice,
      unrealizedPnLRaw: unrealizedPnL,
      breakEvenPriceRaw: breakEvenPrice,
      minimumProfitablePriceRaw: minimumProfitablePrice,
      trailingActive: trailingActive,
      trailingStopRaw: trailingStop,
      sellConditions: sellConditions,
      technicalDetail: technicalDetail
    )
  }
}

extension StrategyExplanationWarningDTO {
  fileprivate func mapped() -> StrategyExplanationWarning {
    let severityModel = StrategyBlockerSeverity(backend: severity)

    return StrategyExplanationWarning(
      id: id,
      severity: severityModel,
      title: title,
      message: message
    )
  }
}

extension StrategyExplanationMetaDTO {
  fileprivate func mapped() -> StrategyExplanationMeta {
    StrategyExplanationMeta(
      requestID: requestID,
      serverTime: serverTime,
      generatedAt: generatedAt,
      source: dataSource
    )
  }
}
