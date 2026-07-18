import SwiftUI

struct AuthenticationPlaceholderView: View {
    let state: AppSessionState
    var body: some View { ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Botaplata").font(.largeTitle.bold()); Text("Authentification serveur non configurée en production. Aucun endpoint réel n'est appelé.").foregroundStyle(BotaplataColors.textSecondary); StatusBadge(status: .neutral, text: "État: \(String(describing: state))") } }.padding() } }
}
