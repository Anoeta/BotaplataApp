import Foundation

enum PremiumValueTone: Sendable {
    case positive, negative, neutral
    static func pnl(_ amount: MoneyAmount?) -> Self {
        guard let value = amount?.value, !value.isNaN, value != 0 else { return .neutral }
        return value > 0 ? .positive : .negative
    }
}

enum PremiumEngineState: Equatable, Sendable {
    case active, observing, stopped, blocked, unknown
    var title: String {
        switch self { case .active: "Actif"; case .observing: "Observation"; case .stopped: "Arrêté"; case .blocked: "Bloqué"; case .unknown: "État inconnu" }
    }
    static func make(session: SessionDetail, cached: Bool) -> Self {
        if session.isHistorical { return .stopped }
        if ["safety_blocked", "reconciliation_blocked", "circuit_breaker", "error", "start_failed"].contains(session.backendStatus ?? "") { return .blocked }
        guard !cached, session.freshness.status == .fresh, session.backendStatus == "running" else { return .unknown }
        if session.lifecycle == .waitingBuy { return .observing }
        return .active
    }
}

enum SessionArchivePresentation {
    static func isHistorical(lifecycle: SessionLifecycleState, status: String?, stoppedAt: Date?) -> Bool {
        lifecycle == .stopped || stoppedAt != nil || ["stopped", "archived", "completed"].contains(status?.lowercased() ?? "")
    }

    static func strategy(name: String?, version: String?) -> String {
        guard let name, !name.isEmpty else { return version.map { "Stratégie · \($0)" } ?? "Stratégie non fournie" }
        guard let version, !version.isEmpty, !name.lowercased().contains(version.lowercased()) else { return name }
        return "\(name) · \(version)"
    }
}

enum PremiumOrderFilter: String, CaseIterable, Identifiable, Sendable {
    case all, buys, sells, pending
    var id: String { rawValue }
    var title: String {
        switch self { case .all: "Tous"; case .buys: "Achats"; case .sells: "Ventes"; case .pending: "En attente" }
    }
    func includes(_ order: SessionOrder) -> Bool {
        switch self {
        case .all: return true
        case .buys: return order.side == .buy
        case .sells: return order.side == .sell
        case .pending:
            switch order.status {
            case .submissionStarted, .submitted, .open, .partiallyFilled, .reconciliationRequired, .reconciliationBlocked, .reconciliationFailed: return true
            case .filled, .rejected, .canceled, .unknown: return false
            }
        }
    }
}
