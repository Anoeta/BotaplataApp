import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationStore.self) private var store
    @Environment(AppState.self) private var appState
    @State private var username = ""
    @State private var password = ""
    @FocusState private var focusedField: LoginField?

    private enum LoginField { case username, password }

    var body: some View {
        @Bindable var store = store
        ZStack {
            PremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: BotaplataSpacing.lg) {
                    AuthHeader(
                        icon: BotaplataSymbol.security,
                        eyebrow: "Accès sécurisé",
                        title: "Bon retour",
                        subtitle: "Connectez-vous pour suivre votre bot Botaplata."
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                            PremiumTextField(title: "Email", text: $username, systemImage: "envelope.fill")
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.next)
                                .accessibilityIdentifier("login.username")
                                .focused($focusedField, equals: .username)
                                .disabled(store.isSubmitting)
                                .onSubmit { focusedField = .password }
                                .accessibilityLabel("Champ email")

                            PremiumSecureField(title: "Mot de passe", text: $password, systemImage: "lock.fill")
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .accessibilityIdentifier("login.password")
                                .focused($focusedField, equals: .password)
                                .disabled(store.isSubmitting)
                                .accessibilityLabel("Champ mot de passe sécurisé")
                                .onSubmit { focusedField = nil; submit() }

                            if case .error(let message) = store.loginPhase {
                                AuthInlineError(message: message)
                                    .accessibilityIdentifier("login.error")
                            }

                            PremiumPrimaryButton(title: store.isSubmitting ? "Connexion…" : "Se connecter", isLoading: store.isSubmitting) { focusedField = nil; submit() }
                                .disabled(!canSubmit)
                                .opacity(canSubmit ? 1 : 0.55)
                                .accessibilityIdentifier("login.submit")
                                .accessibilityHint(canSubmit ? "Valide la connexion au serveur Botaplata" : "Renseignez votre email et votre mot de passe")
                                .accessibilityValue(store.isSubmitting ? "Connexion en cours" : "")
                        }
                    }

                    VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                        StatusPill(status: backendConfigured ? .success : .warning, text: backendConfigured ? "Serveur Botaplata configuré" : "Serveur Botaplata non configuré")
                        Text("Votre iPhone se connecte au serveur Botaplata configuré.")
                            .font(BotaplataTypography.caption)
                            .foregroundStyle(BotaplataColors.textMuted)
#if DEBUG
                        Text("\(appState.environment.name) · backend \(backendConfigured ? "configuré" : "non configuré")")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(BotaplataColors.textMuted)
#endif
                    }
                    .accessibilityElement(children: .combine)
                }
                .padding(BotaplataSpacing.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BotaplataSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var canSubmit: Bool { !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && store.loginPhase != .loading }
    private var backendConfigured: Bool { appState.environment.baseURL != nil }

    private func submit() {
        guard canSubmit else { return }
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password
        focusedField = nil
        Task {
            await store.login(username: u, password: p)
            if store.challenge != nil || appState.sessionState == .authenticated { password = ""; focusedField = nil }
        }
    }
}

struct AuthHeader: View {
    let icon: String
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(BotaplataGradients.buttonPrimary)
                .frame(width: 64, height: 64)
                .background(BotaplataColors.cardGlass, in: RoundedRectangle(cornerRadius: BotaplataRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: BotaplataRadius.lg, style: .continuous).stroke(BotaplataColors.cardBorder, lineWidth: 1))
                .accessibilityHidden(true)
            IconBadge(symbol: "shield.checkered", label: eyebrow, color: BotaplataColors.primaryMint)
            Text(title)
                .font(BotaplataTypography.largeTitle)
                .foregroundStyle(BotaplataColors.textPrimary)
            Text(subtitle)
                .font(BotaplataTypography.body)
                .foregroundStyle(BotaplataColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct AuthInlineError: View {
    let message: String
    var body: some View {
        Label {
            Text(message).font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: BotaplataSymbol.warning)
        }
        .foregroundStyle(BotaplataColors.danger)
        .padding(BotaplataSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BotaplataColors.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: BotaplataRadius.md, style: .continuous))
        .accessibilityLabel("Erreur : \(message)")
    }
}

struct PremiumTextField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        Label {
            TextField(title, text: $text)
                .foregroundStyle(BotaplataColors.textPrimary)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(BotaplataColors.textMuted)
        }
        .padding(BotaplataSpacing.md)
        .background(BotaplataColors.backgroundDeep.opacity(0.38), in: RoundedRectangle(cornerRadius: BotaplataRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BotaplataRadius.md, style: .continuous).stroke(BotaplataColors.cardBorder, lineWidth: 1))
    }
}

struct PremiumSecureField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        Label {
            SecureField(title, text: $text)
                .foregroundStyle(BotaplataColors.textPrimary)
        } icon: {
            Image(systemName: systemImage).foregroundStyle(BotaplataColors.textMuted)
        }
        .padding(BotaplataSpacing.md)
        .background(BotaplataColors.backgroundDeep.opacity(0.38), in: RoundedRectangle(cornerRadius: BotaplataRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: BotaplataRadius.md, style: .continuous).stroke(BotaplataColors.cardBorder, lineWidth: 1))
    }
}

#Preview("Login vide") {
    LoginView()
        .environment(AuthenticationStore.preview())
        .environment(AppState(sessionState: .loggedOut, environment: .debugPreview))
}

#Preview("Login en chargement") {
    let store = AuthenticationStore.preview(loginPhase: .loading)
    LoginView()
        .environment(store)
        .environment(AppState(sessionState: .authenticating, environment: .development))
}

#Preview("Login erreur serveur non configuré") {
    LoginView()
        .environment(AuthenticationStore.preview(loginPhase: .error(AuthenticationError.notConfigured.authDisplayMessage)))
        .environment(AppState(sessionState: .loggedOut, environment: .debugPreview))
}

#Preview("Login erreur identifiants") {
    LoginView()
        .environment(AuthenticationStore.preview(loginPhase: .error(AuthenticationError.invalidCredentials.authDisplayMessage)))
        .environment(AppState(sessionState: .loggedOut, environment: .development))
}
