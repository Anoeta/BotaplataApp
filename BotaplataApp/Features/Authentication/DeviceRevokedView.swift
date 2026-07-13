import SwiftUI

struct DeviceRevokedView: View { @Environment(AuthenticationStore.self) private var store; var body: some View { ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Cet iPhone n'est plus autorisé à accéder à Botaplata.").font(.title.bold()); Text("Pour protéger votre compte, la session locale a été fermée.").foregroundStyle(.secondary); Button("Retour connexion") { Task { await store.logout() } }.buttonStyle(.borderedProminent).accessibilityIdentifier("deviceRevoked.login") } }.padding() } } }
