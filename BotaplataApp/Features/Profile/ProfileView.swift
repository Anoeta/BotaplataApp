import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileContainerView: View {
    @Bindable var store: ProfileStore
    @Bindable var pushStore: PushNotificationsStore
    @Environment(AuthenticationStore.self) private var authStore
    var body: some View { ProfileView(store: store, pushStore: pushStore, lockNow: { authStore.lockLocally() }, logout: { await authStore.logout(); store.purge() }).task { await store.bootstrap(); await pushStore.bootstrap() } }
}

struct ProfileView: View {
    @Bindable var store: ProfileStore
    @Bindable var pushStore: PushNotificationsStore
    let lockNow: () -> Void
    let logout: () async -> Void
    @State private var confirmsLogout = false
    @State private var showingAbout = false
    @State private var showingDiagnostic = false

    var body: some View {
        ZStack { PremiumBackground(); ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { header; stateBanner; securityCard; devicesCard; notificationsCard; serverCard; aboutCard; logoutCard }.padding(BotaplataSpacing.md) } }
            .navigationTitle("Profil")
            .refreshable { await store.bootstrap(); await pushStore.refreshAll() }
            .sheet(isPresented: $showingAbout) { NavigationStack { AboutBotaplataView(diagnostic: store.diagnostic) } }
            .navigationDestination(isPresented: $showingDiagnostic) { DiagnosticView(diagnostic: store.diagnostic, permissionStatus: pushStore.permissionStatus) }
            .alert("Se déconnecter de Botaplata ?", isPresented: $confirmsLogout) { Button("Annuler", role: .cancel) {}; Button("Se déconnecter", role: .destructive) { Task { await logout() } } } message: { Text("Vous devrez saisir à nouveau votre mot de passe et votre code de vérification.") }
            .overlay(alignment: .bottom) { if let message = store.message { Text(message).font(.footnote).padding().background(BotaplataColors.backgroundElevated.opacity(0.96), in: Capsule()).foregroundStyle(BotaplataColors.textPrimary).padding().accessibilityLabel(message) } }
    }

    private var header: some View { ProfileUserCard(user: store.user) }
    @ViewBuilder private var stateBanner: some View { if case .offline(_, let message) = store.devicesContent { PremiumOfflineBanner(); Text(message).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted) } }

    private var securityCard: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { ProfileSectionHeader(title: "Sécurité", icon: "lock.shield", status: "Protégé"); profileRow("Face ID", value: store.biometricText, detail: "Face ID verrouille l’application sur cet iPhone.", symbol: "faceid"); Toggle(isOn: Binding(get: { store.biometricLockEnabled }, set: { value in Task { await store.setBiometricLockEnabled(value) } })) { VStack(alignment: .leading, spacing: 3) { Text("Verrouillage local").font(BotaplataTypography.body); Text(ProfilePresentation.biometricMicrocopy(availability: store.biometricAvailability)).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textSecondary) } }.disabled(store.biometricAvailability != .available && !store.biometricLockEnabled).tint(BotaplataColors.primaryTeal).accessibilityLabel("Face ID, \(store.biometricText). Protège l’accès local à Botaplata."); profileRow("Double vérification", value: "Activée", detail: "Un code à 6 chiffres est demandé lors de la connexion.", symbol: "number.circle"); profileRow("Session actuelle", value: store.currentDevice?.isCurrent == true ? "Cet iPhone" : "Connectée", detail: "Cet appareil est actuellement autorisé à accéder à Botaplata.", symbol: "iphone"); if store.biometricAvailability == .available || store.biometricLockEnabled { PremiumSecondaryButton(title: "Verrouiller maintenant", action: lockNow).accessibilityLabel("Verrouiller Botaplata maintenant") } } } }

    private var devicesCard: some View { NavigationLink { AuthorizedDevicesView(store: store) } label: { PremiumCard { HStack(alignment: .center, spacing: BotaplataSpacing.md) { IconBadge(symbol: "iphone.gen3", label: "Appareils", color: BotaplataColors.primaryMint); VStack(alignment: .leading, spacing: 5) { Text("Appareils autorisés").font(BotaplataTypography.cardTitle); Text(ProfilePresentation.devicesSummary(current: store.currentDevice, others: store.otherDevices.count)).foregroundStyle(BotaplataColors.textSecondary); Text("Gérer les appareils").font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.primaryMint) }; Spacer(); Image(systemName: "chevron.right").foregroundStyle(BotaplataColors.textMuted) } } }.buttonStyle(.plain).accessibilityLabel("Appareils autorisés, \(ProfilePresentation.devicesSummary(current: store.currentDevice, others: store.otherDevices.count))") }

    private var notificationsCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                ProfileSectionHeader(title: "Notifications", icon: "bell.badge", status: ProfilePresentation.permissionText(pushStore.permissionStatus))
                Text("Botaplata peut vous prévenir lorsqu’un événement important demande votre attention.").font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textSecondary)
                if pushStore.permissionStatus == .denied {
                    PremiumCard(variant: .warning) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications désactivées").font(BotaplataTypography.cardTitle)
                            Text("Autorisez les notifications dans les Réglages de l’iPhone pour recevoir les alertes Botaplata.").foregroundStyle(BotaplataColors.textSecondary)
                            settingsLink
                        }
                    }
                } else if pushStore.permissionStatus == .notDetermined {
                    PremiumSecondaryButton(title: "Activer les notifications") { Task { await pushStore.requestPermission() } }
                }
                preferencesSummary
                NavigationLink { PushPreferencesView(store: pushStore) } label: { HStack { Text("Réglages des notifications").font(BotaplataTypography.body); Spacer(); Image(systemName: "chevron.right") } }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var settingsLink: some View {
        #if canImport(UIKit)
        Link("Ouvrir les Réglages", destination: URL(string: UIApplication.openSettingsURLString)!).foregroundStyle(BotaplataColors.primaryMint)
        #endif
    }

    @ViewBuilder private var preferencesSummary: some View { let prefs = ProfilePresentation.preferenceRows(pushStore.currentPreferencesSnapshot()); ForEach(prefs.prefix(4), id: \.title) { row in profileRow(row.title, value: row.value, detail: row.detail, symbol: row.symbol) } }
    private var serverCard: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { ProfileSectionHeader(title: "Serveur Botaplata", icon: "server.rack", status: store.diagnostic.isBackendConfigured ? "Connecté" : "Non configuré"); profileRow("Statut", value: store.diagnostic.isBackendConfigured ? "Connecté" : "Indisponible", detail: nil, symbol: "network"); profileRow("Environnement", value: store.diagnostic.environment, detail: nil, symbol: "shippingbox"); profileRow("Dernière synchronisation", value: ProfilePresentation.lastSyncText(pushStore.summary?.latestCreatedAt), detail: "Dernier état connu affiché lorsque le serveur est indisponible.", symbol: "clock"); Button { showingDiagnostic = true } label: { HStack { Text("Diagnostic léger"); Spacer(); Image(systemName: "chevron.right") } }.foregroundStyle(BotaplataColors.primaryMint) } } }
    private var aboutCard: some View { PremiumCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { ProfileSectionHeader(title: "À propos", icon: "info.circle", status: "Version \(store.diagnostic.appVersion)"); profileRow("Botaplata", value: "Version \(store.diagnostic.appVersion) (\(store.diagnostic.build))", detail: "Supervision sécurisée de votre bot Kraken.", symbol: "app.badge"); profileRow("Vos données", value: "Protégées", detail: "Les identifiants Kraken restent sur votre serveur Botaplata. Cet iPhone ne stocke aucune clé Kraken.", symbol: "key.slash"); Button { showingAbout = true } label: { HStack { Text("Fonctionnement de l’app"); Spacer(); Image(systemName: "chevron.right") } }.foregroundStyle(BotaplataColors.primaryMint) } } }
    private var logoutCard: some View { PremiumCard(variant: .danger) { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { Text("Déconnexion").font(BotaplataTypography.cardTitle); Text("La session locale sera supprimée. L’onboarding déjà terminé reste conservé.").foregroundStyle(BotaplataColors.textSecondary); PremiumDangerButton(title: "Se déconnecter") { confirmsLogout = true }.accessibilityLabel("Se déconnecter de Botaplata") } } }

    private func profileRow(_ title: String, value: String, detail: String?, symbol: String) -> some View { HStack(alignment: .top, spacing: BotaplataSpacing.sm) { Image(systemName: symbol).foregroundStyle(BotaplataColors.primaryMint).frame(width: 24); VStack(alignment: .leading, spacing: 3) { HStack { Text(title).font(BotaplataTypography.body); Spacer(); Text(value).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textSecondary) }; if let detail { Text(detail).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted).fixedSize(horizontal: false, vertical: true) } } }.accessibilityElement(children: .combine) }
}

struct ProfileUserCard: View { let user: AuthenticatedUser?; var body: some View { PremiumCard(variant: .hero) { HStack(alignment: .center, spacing: BotaplataSpacing.md) { ZStack { Circle().fill(BotaplataColors.primaryTeal.opacity(0.24)).frame(width: 68, height: 68); Text(ProfilePresentation.initials(for: user)).font(.title2.bold()).foregroundStyle(BotaplataColors.primaryMint) }; VStack(alignment: .leading, spacing: 5) { Text(ProfilePresentation.displayName(for: user)).font(BotaplataTypography.largeTitle).minimumScaleFactor(0.7); if let email = ProfilePresentation.email(for: user) { Text(email).foregroundStyle(BotaplataColors.textSecondary) }; StatusPill(status: .success, text: "Connexion sécurisée") } } }.accessibilityElement(children: .combine) } }
struct ProfileSectionHeader: View { let title: String; let icon: String; let status: String; var body: some View { HStack { Label(title, systemImage: icon).font(BotaplataTypography.cardTitle); Spacer(); StatusPill(status: .active, text: status) } } }

struct AuthorizedDevicesView: View {
    @Bindable var store: ProfileStore
    @State private var pending: AuthorizedDevice?
    var body: some View { ZStack { PremiumBackground(); ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { content }.padding(BotaplataSpacing.md) } }.navigationTitle("Appareils autorisés").refreshable { await store.refreshDevices() }.task { await store.refreshDevices() }.alert((pending?.isCurrent == true) ? "Révoquer cet iPhone ?" : "Révoquer cet appareil ?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) { Button("Annuler", role: .cancel) { pending = nil }; Button("Révoquer", role: .destructive) { if let device = pending { Task { await store.revoke(device) } }; pending = nil } } message: { Text("Cet appareil ne pourra plus accéder à Botaplata sans une nouvelle autorisation.") } }
    @ViewBuilder private var content: some View { switch store.devicesContent { case .idle, .loading: PremiumSkeletonCard(); PremiumSkeletonCard(); case .failed(let message): PremiumErrorState(title: "Impossible d’actualiser les appareils", message: message); case .offline(let devices, let message): PremiumOfflineBanner(); Text(message).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted); deviceSections(devices); case .refreshing(let devices), .loaded(let devices): if devices.isEmpty { PremiumEmptyState(title: "Aucun appareil autorisé", message: "Les appareils autorisés apparaîtront ici après une connexion sécurisée.", systemImage: "iphone.slash") } else { deviceSections(devices) } } }
    @ViewBuilder private func deviceSections(_ devices: [AuthorizedDevice]) -> some View { ForEach(devices.sorted { $0.isCurrent && !$1.isCurrent }) { PremiumDeviceCard(device: $0, revoke: { pending = $0 }) } }
}

struct PremiumDeviceCard: View { let device: AuthorizedDevice; let revoke: (AuthorizedDevice) -> Void; var body: some View { PremiumCard(variant: device.isRevoked ? .danger : device.isCurrent ? .success : .normal) { VStack(alignment: .leading, spacing: BotaplataSpacing.sm) { HStack(alignment: .top) { IconBadge(symbol: device.isCurrent ? "iphone.gen3" : "iphone", label: device.isCurrent ? "Cet iPhone" : "Appareil", color: device.isCurrent ? BotaplataColors.success : BotaplataColors.primaryMint); Spacer(); StatusPill(status: device.isRevoked ? .danger : device.isCurrent ? .success : .active, text: device.isRevoked ? "Révoqué" : device.isCurrent ? "Appareil actuel" : "Autorisé") }; Text(device.isCurrent ? "Cet iPhone" : ProfilePresentation.deviceTitle(device)).font(BotaplataTypography.cardTitle); Text([device.model, device.osVersion, "App \(device.appVersion)"].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundStyle(BotaplataColors.textSecondary); Text(ProfilePresentation.activityText(device)).font(BotaplataTypography.caption).foregroundStyle(BotaplataColors.textMuted); if !device.isCurrent && !device.isRevoked { PremiumDangerButton(title: "Révoquer") { revoke(device) }.accessibilityLabel("Révoquer l’appareil \(ProfilePresentation.deviceTitle(device))") } } }.accessibilityElement(children: .combine).accessibilityLabel("Appareil autorisé, \(device.isCurrent ? "cet iPhone" : ProfilePresentation.deviceTitle(device)), \(ProfilePresentation.activityText(device))") } }

struct DiagnosticView: View {
    let diagnostic: ProfileDiagnostic
    var permissionStatus: PushAuthorizationStatus = .unknown
    @State private var entries: [NetworkDiagnosticEntry] = []

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                            Text("Diagnostic Botaplata").font(BotaplataTypography.cardTitle)
                            diag("URL serveur", diagnostic.serverURL)
                            diag("État réseau", diagnostic.isBackendConfigured ? "Serveur configuré" : "Non configuré")
                            diag("Dernier health check", last(feature: "Diagnostics"))
                            diag("Dernier login", last(endpointContains: "/auth/login"))
                            diag("Dernier refresh token", last(endpointContains: "/auth/refresh"))
                            diag("Dernier Dashboard", last(feature: "Dashboard"))
                            diag("Dernière liste Sessions", last(endpointContains: "/real/sessions"))
                            diag("Dernier détail session", lastDetail())
                            diag("Historique mémoire", "\(entries.count)/50 requêtes")
                        }
                    }
                    PremiumCard {
                        VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                            Text("Actions Debug").font(BotaplataTypography.cardTitle)
                            Button("Tester le serveur") { Task { await reloadDiagnostics() } }
                            Button("Copier le diagnostic") { copyDiagnostic() }
                            Button("Effacer les métriques") { Task { await NetworkDiagnosticsStore.shared.reset(); await reloadDiagnostics() } }
                        }
                    }
                    if !entries.isEmpty {
                        PremiumCard {
                            VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                                Text("Dernières requêtes").font(BotaplataTypography.cardTitle)
                                ForEach(entries.suffix(10)) { entry in
                                    diag("[\(entry.requestID)] \(entry.method) \(entry.endpoint)", "\(entry.result.rawValue) · \(String(format: "%.3f", entry.duration))s · \(entry.statusCode.map(String.init) ?? "—")")
                                }
                            }
                        }
                    }
                    PremiumCard {
                        VStack(alignment: .leading, spacing: BotaplataSpacing.sm) {
                            Text("Informations techniques").font(BotaplataTypography.cardTitle)
                            diag("Version app", diagnostic.appVersion)
                            diag("Build", diagnostic.build)
                            diag("Environnement", diagnostic.environment)
                            diag("Session", diagnostic.authenticationState)
                            diag("Notifications", ProfilePresentation.permissionText(permissionStatus))
                            diag("Biométrie", diagnostic.biometricState)
                        }
                    }
                }
                .padding(BotaplataSpacing.md)
            }
        }
        .navigationTitle("Diagnostic")
        .task { await reloadDiagnostics() }
    }

    private func reloadDiagnostics() async { entries = await NetworkDiagnosticsStore.shared.snapshot() }
    private func last(feature: String) -> String { entries.last { $0.feature == feature }.map(summary) ?? "aucun" }
    private func last(endpointContains value: String) -> String { entries.last { $0.endpoint.contains(value) }.map(summary) ?? "aucun" }
    private func lastDetail() -> String { entries.last { $0.endpoint.contains("/real/sessions/") && !$0.endpoint.contains("chart") }.map(summary) ?? "aucun" }
    private func summary(_ entry: NetworkDiagnosticEntry) -> String { "\(entry.result.rawValue) · \(String(format: "%.3f", entry.duration))s · HTTP \(entry.statusCode.map(String.init) ?? "—") · cache \(entry.cacheStatus.rawValue)" }
    private func copyDiagnostic() {
        let text = ([diagnostic.sanitizedText] + entries.map { "[\($0.requestID)] \($0.method) \($0.endpoint) \($0.feature) \($0.result.rawValue) \(String(format: "%.3f", $0.duration))s" }).joined(separator: "\n")
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
    private func diag(_ title: String, _ value: String) -> some View { HStack(alignment: .top) { Text(title); Spacer(); Text(value).foregroundStyle(BotaplataColors.textSecondary).multilineTextAlignment(.trailing) }.font(BotaplataTypography.body).accessibilityElement(children: .combine) }
}

struct AboutBotaplataView: View { let diagnostic: ProfileDiagnostic; var body: some View { ZStack { PremiumBackground(); ScrollView { LazyVStack(alignment: .leading, spacing: BotaplataSpacing.md) { PremiumCard(variant: .hero) { VStack(alignment: .leading, spacing: 8) { Text("Botaplata").font(BotaplataTypography.largeTitle); Text("Version \(diagnostic.appVersion) (\(diagnostic.build))").foregroundStyle(BotaplataColors.textSecondary); Text("Supervision sécurisée de votre bot Kraken.").font(BotaplataTypography.body) } }; PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Fonctionnement de l’app").font(BotaplataTypography.cardTitle); Text("Botaplata affiche les informations fournies par votre serveur personnel. L’application ne contacte jamais Kraken directement et ne permet pas d’envoyer manuellement des ordres.").foregroundStyle(BotaplataColors.textSecondary) } }; PremiumCard { VStack(alignment: .leading, spacing: 8) { Text("Vos données").font(BotaplataTypography.cardTitle); Text("Les identifiants Kraken restent sur votre serveur Botaplata. Cet iPhone ne stocke aucune clé Kraken. Le refresh token est protégé par le Trousseau de l’iPhone.").foregroundStyle(BotaplataColors.textSecondary) } } }.padding(BotaplataSpacing.md) } }.navigationTitle("À propos") } }

#Preview("Profil nominal") { NavigationStack { ProfileView(store: .preview(), pushStore: .preview(), lockNow: {}, logout: {}) } }
#Preview("Profil Face ID indisponible") { NavigationStack { ProfileView(store: .preview(availability: .unavailable), pushStore: .preview(status: .denied), lockNow: {}, logout: {}) } }
#Preview("Appareils") { NavigationStack { AuthorizedDevicesView(store: .preview()) } }
#Preview("Diagnostic") { DiagnosticView(diagnostic: ProfileStore.preview().diagnostic, permissionStatus: .authorized) }
