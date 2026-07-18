import Foundation

enum SessionFreshnessPresentation {
    static func text(for freshness: DataFreshness) -> String {
        switch freshness.status {
        case .fresh:
            return "Données fraîches"
        case .aging:
            return "Actualisation ralentie"
        case .stale:
            return "Données anciennes"
        case .cached:
            return "Dernier état connu"
        case .unknown:
            return "Fraîcheur inconnue"
        }
    }

    static func relativeText(for freshness: DataFreshness, now: Date = Date()) -> String {
        guard let date = freshness.updatedAt else {
            return text(for: freshness)
        }

        let seconds = max(0, Int(now.timeIntervalSince(date)))
        switch freshness.status {
        case .stale:
            return "Dernière donnée connue il y a \(relative(seconds))"
        case .fresh, .aging, .cached:
            return "Mis à jour il y a \(relative(seconds))"
        case .unknown:
            return text(for: freshness)
        }
    }

    private static func relative(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) s" }
        if seconds < 3_600 { return "\(seconds / 60) min" }
        return "\(seconds / 3_600) h"
    }
}
