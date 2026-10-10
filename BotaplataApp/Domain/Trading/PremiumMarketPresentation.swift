import Foundation

/// Presentation of persisted observations. Never synthesizes candles, indicators or returns.
struct MarketPricePoint: Identifiable, Equatable {
    let id: String
    let date: Date
    let price: Double
    let segment: Int
}

struct MarketHistoryGap: Identifiable, Equatable {
    let start: Date
    let end: Date
    var id: Date { start }
}

struct PremiumMarketPresentation {
    let points: [MarketPricePoint]
    let gaps: [MarketHistoryGap]
    let change: Decimal?
    let firstObservation: Date?
    let lastObservation: Date?
    let domain: ClosedRange<Double>

    init(chart: TradingChart) {
        let candles = chart.candles.filter { $0.close > 0 && NSDecimalNumber(decimal: $0.close).doubleValue.isFinite }.sorted { $0.closeTime < $1.closeTime }
        var points: [MarketPricePoint] = []
        var gaps: [MarketHistoryGap] = []
        var segment = 0
        var previous: TradingCandle?
        for candle in candles {
            if let previous, candle.openTime > previous.closeTime.addingTimeInterval(1) {
                gaps.append(MarketHistoryGap(start: previous.closeTime, end: candle.openTime))
                segment += 1
            }
            let price = NSDecimalNumber(decimal: candle.close).doubleValue
            guard price.isFinite, price > 0 else { continue }
            points.append(MarketPricePoint(id: candle.id, date: candle.closeTime, price: price, segment: segment))
            previous = candle
        }
        self.points = points
        self.gaps = gaps
        firstObservation = points.first?.date
        lastObservation = points.last?.date
        // A return across missing observations would hide missing data.
        if gaps.isEmpty, points.count > 1, let first = candles.first, let last = candles.last, first.close > 0 {
            change = (last.close - first.close) / first.close
        } else {
            change = nil
        }
        let low = points.map(\.price).min() ?? 0
        let high = points.map(\.price).max() ?? 1
        let padding = max((high - low) * 0.12, max(high * 0.002, 0.01))
        domain = max(0, low - padding)...(high + padding)
    }

    func nearest(to date: Date) -> MarketPricePoint? {
        // Refuse to select an invented observation inside a history gap.
        guard !gaps.contains(where: { $0.start < date && date < $0.end }) else { return nil }
        return points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}

enum SupervisionState: Equatable {
    case healthy, degraded, blocked, unknown
    var title: String {
        switch self { case .healthy: "Surveillance OK"; case .degraded: "Surveillance dégradée"; case .blocked: "Sécurité bloquée"; case .unknown: "Surveillance inconnue" }
    }
}

enum PremiumSupervisionPresentation {
    static func state(session: SessionDetail, cached: Bool) -> SupervisionState {
        if ["safety_blocked", "reconciliation_blocked", "circuit_breaker", "error", "start_failed"].contains(session.backendStatus ?? "") { return .blocked }
        guard !cached else { return .unknown }
        if session.runtimeHealth == .degraded || session.runtimeHealth == .unavailable || session.freshness.status == .stale || session.freshness.status == .aging { return .degraded }
        guard session.runtimeHealth == .healthy, session.freshness.status == .fresh,
              session.backendStatus == "running" else { return .unknown }
        return .healthy
    }
}

enum PremiumIndicatorPresentation {
    static func status(_ indicator: StrategyIndicator) -> String {
        guard let raw = indicator.valueRaw, !raw.isEmpty else { return "Indisponible" }
        switch indicator.status {
        case "favorable", "ok", "validated": return "Favorable"
        case "unfavorable", "blocked", "veto": return "Défavorable à l’entrée"
        case "unavailable", "invalid": return "Valeur reçue · qualité à vérifier"
        default: return "Disponible · condition à confirmer"
        }
    }
}
