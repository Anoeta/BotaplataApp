import SwiftUI

struct PremiumEngineCard: View {
    let session: SessionDetail
    let cached: Bool
    private var state: PremiumEngineState { .make(session: session, cached: cached) }
    private var badge: BadgeStatus {
        switch state { case .active: .success; case .observing: .waiting; case .stopped, .unknown: .neutral; case .blocked: .danger }
    }
    var body: some View {
        PremiumCard {
            PremiumEyebrow(title: "Moteur de la session réelle")
            PremiumStatusBadge(status: badge, text: state.title)
            Text(SessionArchivePresentation.strategy(name: session.strategyName, version: session.strategyVersion))
                .font(BotaplataTypography.sectionTitle)
            Text("Session \(session.id) · \(session.pair) · \(session.provider.displayName)")
                .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
            if cached { Text("Dernier état connu · fonctionnement actuel non confirmé").font(.caption).foregroundStyle(BotaplataColors.warning) }
            if session.isHistorical { Text("Session terminée · aucun moteur actif certifié par cet écran").font(.caption).foregroundStyle(BotaplataColors.textSecondary) }
        }.accessibilityElement(children: .combine)
    }
}
