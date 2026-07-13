import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationStore.self) private var store
    @State private var username = ""
    @State private var password = ""
    var body: some View { @Bindable var store = store; ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Connexion Botaplata").font(.title.bold()); TextField("Identifiant", text: $username).textContentType(.username).submitLabel(.next).accessibilityIdentifier("login.username"); SecureField("Mot de passe", text: $password).textContentType(.password).submitLabel(.go).accessibilityIdentifier("login.password").onSubmit { submit() }; if case .error(let message) = store.loginPhase { Text(message).foregroundStyle(.red).accessibilityIdentifier("login.error") }; Button(store.loginPhase == .loading ? "Connexion…" : "Se connecter") { submit() }.disabled(username.isEmpty || password.isEmpty || store.loginPhase == .loading).buttonStyle(.borderedProminent).accessibilityIdentifier("login.submit") } }.padding() } }
    private func submit() { let u = username; let p = password; password = ""; Task { await store.login(username: u, password: p) } }
}
