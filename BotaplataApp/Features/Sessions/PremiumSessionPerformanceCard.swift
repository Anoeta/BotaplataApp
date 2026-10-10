import SwiftUI

/// Values supplied by the real-session contract; missing amounts remain missing.
struct PremiumSessionPerformanceCard: View {
    let session: SessionDetail
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), alignment: .leading), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                Text("Résultat de la session").font(.headline).accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, alignment: .leading, spacing: BotaplataSpacing.md) {
                    metric(session.pnl?.realizedNet?.value == nil ? "P&L réalisé brut" : "P&L réalisé net", session.pnl?.realizedNet ?? session.pnl?.realizedGross)
                    metric("P&L latent net estimé", session.pnl?.netEstimated ?? session.feeAware.unrealizedPnLNetEstimatedQuote)
                    metric("Valeur estimée de position", session.position?.estimatedValueQuote)
                    metric("Frais d’achat constatés", session.feeAware.buyFeeQuote)
                }
                DisclosureGroup("Capital et détails financiers") {
                    VStack(spacing: 10) {
                        PremiumKeyValueRow(label: "Capital autorisé", value: "Non fourni")
                        PremiumKeyValueRow(label: "Capital engagé", value: "Non fourni")
                        PremiumKeyValueRow(label: "Solde de session", value: "Non fourni")
                        PremiumKeyValueRow(label: "Performance %", value: "Non certifiée")
                        PremiumKeyValueRow(label: "P&L latent brut", value: FinancialFormatters.money(session.pnl?.gross), monospaced: true)
                        PremiumKeyValueRow(label: "Frais de vente estimés", value: FinancialFormatters.money(session.feeAware.estimatedSellFeeQuote), monospaced: true)
                        Text("Le contrat réel ne fournit pas le capital ni le solde de session. Le solde global Kraken ne les remplace pas. Le réalisé brut ne certifie pas un résultat net de frais. Le net latent reste une estimation.")
                            .font(.caption).foregroundStyle(BotaplataColors.textSecondary)
                    }.padding(.top, 10)
                }.font(.subheadline)
            }
        }
    }
    private func metric(_ title: String, _ amount: MoneyAmount?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(BotaplataColors.textSecondary)
            Text(amount?.value == nil ? "Indisponible" : FinancialFormatters.money(amount))
                .font(.title3.bold().monospacedDigit()).foregroundStyle(BotaplataColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }
}
