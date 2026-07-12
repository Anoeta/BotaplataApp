import SwiftUI

struct AuthenticationPlaceholderView: View {
    let state: AppSessionState
    var body: some View {
        ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Botaplata").font(.largeTitle.bold()); Text("Fondation d'authentification prête pour login, 2FA et verrou local. Aucun réseau n'est appelé dans ce lot.").foregroundStyle(.secondary); StatusBadge(status: .neutral, text: "État: \(String(describing: state))") } }.padding() }
    }
}
