import SwiftUI
struct ProfileView: View { let profile: [String]; var body: some View { List { Section("Démo locale") { Text("Données fictives neutres — aucun profil réel."); Text(PreviewFixtureMetadata.source) } Section("Sections") { ForEach(profile, id: \.self) { Label($0, systemImage: "chevron.right.circle") } } }.navigationTitle("Profil").scrollContentBackground(.hidden).background(BotaplataColors.background) } }
#Preview { NavigationStack { ProfileView(profile: PreviewFixtures.profile) } }
