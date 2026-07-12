import SwiftUI

struct DashboardView: View { let summary: DashboardSummary
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { header; Text(summary.fixtureNotice).font(.caption).foregroundStyle(BotaplataColors.warning); ForEach(summary.warnings) { WarningBanner(warning: $0) }; health; if let session = summary.activeSession { SessionDetailContent(session: session, compact: true) } else { EmptyStateView(title: "Aucune session active", message: "Botaplata affichera ici la prochaine session fournie par le backend.") } }.padding() }.background(BotaplataColors.background.ignoresSafeArea()).navigationTitle("Dashboard") }
    var header: some View { HStack { VStack(alignment: .leading) { Text("Bonjour").foregroundStyle(.secondary); Text("Botaplata").font(.largeTitle.bold()) }; Spacer(); Button {} label: { Image(systemName: "bell.slash").frame(width: BotaplataTouch.minimum, height: BotaplataTouch.minimum) }.disabled(true).accessibilityLabel("Alertes non fonctionnelles dans cette fondation") } }
    var health: some View { BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text(summary.systemHealth.message).font(.headline); HStack { StatusBadge(status: .success, text: "Raspberry disponible"); ProviderBadge(provider: .kraken) }; StatusBadge(status: summary.systemHealth.monitoring == .healthy ? .success : .warning, text: summary.systemHealth.monitoring.label) } } }
}
#Preview { NavigationStack { DashboardView(summary: PreviewFixtures.dashboardNominalKraken) } }
