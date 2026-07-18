import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    private let benefits = [
        ("Suivi clair des sessions", "chart.line.uptrend.xyaxis"),
        ("Alertes importantes", BotaplataSymbol.alerts),
        ("Données sécurisées", BotaplataSymbol.security)
    ]

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: BotaplataSpacing.lg) {
                    AuthHeader(
                        icon: "sparkles",
                        eyebrow: "Botaplata iOS",
                        title: "Botaplata surveille votre bot.",
                        subtitle: "Suivez vos sessions Kraken, vos positions et vos alertes importantes depuis votre iPhone."
                    )

                    PremiumCard(variant: .hero) {
                        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                            ForEach(benefits, id: \.0) { benefit in
                                Label {
                                    Text(benefit.0)
                                        .font(BotaplataTypography.cardTitle)
                                } icon: {
                                    Image(systemName: benefit.1)
                                        .foregroundStyle(BotaplataColors.primaryMint)
                                }
                            }
                        }
                    }

                    VStack(spacing: BotaplataSpacing.sm) {
                        PremiumPrimaryButton(title: "Commencer", action: onContinue)
                            .accessibilityIdentifier("onboarding.continue")
                        PremiumSecondaryButton(title: "J’ai déjà un accès", action: onContinue)
                            .accessibilityIdentifier("onboarding.existingAccess")
                    }

                    Text("Compte créé côté serveur. Demandez l’accès à l’administrateur Botaplata.")
                        .font(BotaplataTypography.caption)
                        .foregroundStyle(BotaplataColors.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(BotaplataSpacing.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BotaplataSpacing.xl)
            }
        }
    }
}

#Preview("Onboarding premium") {
    OnboardingView(onContinue: {})
}
