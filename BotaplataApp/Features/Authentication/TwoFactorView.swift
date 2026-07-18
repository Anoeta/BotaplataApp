import SwiftUI

struct TwoFactorView: View {
    @Environment(AuthenticationStore.self) private var store
    @State private var code = ""

    var body: some View {
        @Bindable var store = store
        ZStack {
            PremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: BotaplataSpacing.lg) {
                    AuthHeader(
                        icon: "lock.rotation",
                        eyebrow: "Double authentification",
                        title: "Vérification sécurisée",
                        subtitle: "Saisissez le code à 6 chiffres de votre application d’authentification."
                    )

                    GlassCard {
                        VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                            PremiumTextField(title: "Code à 6 chiffres", text: Binding(get: { code }, set: { code = String($0.filter(\.isNumber).prefix(6)) }), systemImage: "number")
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .submitLabel(.done)
                                .accessibilityIdentifier("twofactor.code")
                                .accessibilityLabel("Champ code à 6 chiffres")

                            if let attempts = store.challenge?.attemptsRemaining {
                                StatusPill(status: .warning, text: "Essais restants : \(attempts)")
                            }

                            if case .error(let message) = store.twoFactorPhase {
                                AuthInlineError(message: message)
                                    .accessibilityIdentifier("twofactor.error")
                            }

                            PremiumPrimaryButton(title: "Valider", isLoading: store.twoFactorPhase == .validating) { submit() }
                                .disabled(!canSubmit)
                                .opacity(canSubmit ? 1 : 0.55)
                                .accessibilityIdentifier("twofactor.submit")

                            PremiumSecondaryButton(title: "Changer de compte") {
                                code = ""
                                Task { await store.logout() }
                            }
                            .accessibilityIdentifier("twofactor.changeAccount")
                        }
                    }
                }
                .padding(BotaplataSpacing.lg)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.vertical, BotaplataSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var canSubmit: Bool { code.count == 6 && store.twoFactorPhase != .validating }

    private func submit() {
        guard canSubmit else { return }
        let submitted = code
        code = ""
        Task { await store.verify(code: submitted) }
    }
}

#Preview("2FA vide") {
    TwoFactorView()
        .environment(AuthenticationStore.preview(challenge: TwoFactorChallenge(id: "preview", challengeType: "totp", expiresAt: Date().addingTimeInterval(300), attemptsRemaining: 3)))
}

#Preview("2FA erreur code incorrect") {
    TwoFactorView()
        .environment(AuthenticationStore.preview(twoFactorPhase: .error(AuthenticationError.invalidTwoFactorCode.authDisplayMessage), challenge: TwoFactorChallenge(id: "preview", challengeType: "totp", expiresAt: Date().addingTimeInterval(300), attemptsRemaining: 2)))
}
