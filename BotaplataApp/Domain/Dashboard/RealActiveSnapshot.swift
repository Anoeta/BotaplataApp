import Foundation

struct RealActiveSnapshot: Equatable, Sendable, Codable { let generatedAt: Date?; let activeSessionCount: Int?; let activeSession: SessionDetail?; let warnings: [Warning]; let requestID: String?; let serverTime: Date? }

enum DashboardPresentation {
    static func wording(for state: SessionLifecycleState) -> (title: String, text: String) { switch state { case .waitingBuy: ("Recherche d'une opportunité", "Botaplata surveille le marché et attend que les conditions d'achat soient réunies."); case .waitingBuyFill: ("Ordre d'achat en attente", "L'ordre d'achat est en attente sur Kraken."); case .waitingSell, .positionOpen, .monitoringPosition: ("Position ouverte", "Botaplata surveille maintenant les conditions de sortie."); case .waitingSellFill: ("Ordre de vente en attente", "L'ordre de vente est en attente de confirmation sur Kraken."); case .reconciliationPending: ("Vérification en cours", "Botaplata vérifie encore l'état de cet ordre sur Kraken."); case .stopped: ("Session arrêtée", "Cette session n'est plus en cours d'exécution."); case .preparingBuy: ("Préparation d'achat", "Botaplata prépare une intention d'achat. Aucun achat n'est envoyé depuis l'app."); case .unknown: ("État à vérifier", "Botaplata ne dispose pas encore de suffisamment d'informations pour confirmer l'état actuel.") } }
    static func globalMessage(health: RuntimeHealthState?) -> String { health == .healthy ? "Botaplata fonctionne normalement" : health == .degraded ? "La surveillance rencontre actuellement un problème." : "État de surveillance inconnu" }
}
