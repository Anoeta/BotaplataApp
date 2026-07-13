import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    private let pages = [("Votre robot, en un coup d'œil.", "Suivez l'activité de Botaplata, ses décisions et l'état de vos sessions depuis votre iPhone."), ("Kraken reste côté serveur.", "L'application ne contient aucune clé Kraken et n'envoie jamais d'ordre directement à la plateforme."), ("Comprendre avant d'agir.", "Botaplata vous explique ce qu'il surveille, pourquoi il attend et si les données sont à jour.")]
    var body: some View { ZStack { BotaplataColors.background.ignoresSafeArea(); TabView { ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text(page.0).font(.title.bold()); Text(page.1).font(.body).foregroundStyle(.secondary); if idx == pages.count - 1 { Button("Continuer", action: onContinue).buttonStyle(.borderedProminent).accessibilityIdentifier("onboarding.continue") } } }.padding().accessibilityElement(children: .combine) } }.tabViewStyle(.page) } }
}
