import SwiftUI

struct BiometricLockView: View {
    @Environment(AuthenticationStore.self) private var store
    let authenticator: BiometricAuthenticating
    @State private var result: BiometricResult?
    var body: some View { ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Déverrouiller Botaplata").font(.title.bold()); Text("Face ID protège l'accès local aux informations affichées sur cet iPhone.").foregroundStyle(BotaplataColors.textSecondary); if let result { Text(message(for: result)).foregroundStyle(result == .succeeded ? .green : .red) }; Button("Déverrouiller Botaplata") { Task { let r = await authenticator.authenticate(reason: "Déverrouiller Botaplata"); result = r; if r == .succeeded { store.unlockLocally() } } }.buttonStyle(.borderedProminent); Button("Se déconnecter") { Task { await store.logout() } }.buttonStyle(.borderless) } }.padding() } }
    private func message(for result: BiometricResult) -> String { switch result { case .succeeded: "Déverrouillage réussi."; case .denied: "Face ID refusé."; case .cancelled: "Déverrouillage annulé."; case .unavailable: "Face ID indisponible." } }
}
