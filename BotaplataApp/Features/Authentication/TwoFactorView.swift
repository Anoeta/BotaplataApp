import SwiftUI

struct TwoFactorView: View {
    @Environment(AuthenticationStore.self) private var store
    @State private var code = ""
    var body: some View { @Bindable var store = store; ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Vérification en deux étapes").font(.title.bold()); Text("Saisissez le code à 6 chiffres de votre application d'authentification.").foregroundStyle(.secondary); TextField("123456", text: Binding(get: { code }, set: { code = String($0.filter(\.isNumber).prefix(6)) })).keyboardType(.numberPad).textContentType(.oneTimeCode).accessibilityIdentifier("twofactor.code"); if let attempts = store.challenge?.attemptsRemaining { Text("Essais restants : \(attempts)").font(.footnote).foregroundStyle(.secondary) }; if case .error(let message) = store.twoFactorPhase { Text(message).foregroundStyle(.red).accessibilityIdentifier("twofactor.error") }; Button(store.twoFactorPhase == .validating ? "Validation…" : "Valider") { let submitted = code; code = ""; Task { await store.verify(code: submitted) } }.disabled(code.count != 6 || store.twoFactorPhase == .validating).buttonStyle(.borderedProminent).accessibilityIdentifier("twofactor.submit"); Button("Retour connexion") { code = ""; store.challenge = nil; store.appStateHackLoggedOut() }.buttonStyle(.borderless) } }.padding() } }
}

private extension AuthenticationStore { func appStateHackLoggedOut() { Task { await logout() } } }
