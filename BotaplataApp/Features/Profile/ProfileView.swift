import SwiftUI

struct ProfileContainerView: View {
    @Bindable var store: ProfileStore
    @Environment(AuthenticationStore.self) private var authStore
    var body: some View { ProfileView(store: store, lockNow: { authStore.lockLocally() }, logout: { await authStore.logout(); store.purge() }).task { await store.bootstrap() } }
}

struct ProfileView: View {
    @Bindable var store: ProfileStore
    let lockNow: () -> Void
    let logout: () async -> Void
    @State private var confirmsLogout = false
    var body: some View {
        List {
            Section { VStack(alignment: .leading, spacing: 8) { Text(store.user?.displayName ?? "Profil").font(.largeTitle.bold()); Text("Session sécurisée").foregroundStyle(.secondary); if store.accessSummary == "Lecture seule" { Text("Lecture seule").font(.caption).padding(6).background(.thinMaterial, in: Capsule()) } } }
            Section("Mon compte") { LabeledContent("Nom", value: store.user?.displayName ?? "—"); LabeledContent("Accès mobile", value: store.accessSummary); LabeledContent("Connexion", value: "Vérifiée avec double authentification") }
            Section("Sécurité") { LabeledContent("Double authentification", value: "Connexion vérifiée"); Toggle(isOn: Binding(get: { store.biometricLockEnabled }, set: { value in Task { await store.setBiometricLockEnabled(value) } })) { VStack(alignment: .leading) { Text("Verrouillage biométrique"); Text("Protège localement l'accès aux informations affichées.").font(.caption).foregroundStyle(.secondary) } }; LabeledContent("État", value: store.biometricText); if store.biometricAvailability == .available || store.biometricLockEnabled { Button("Verrouiller maintenant", action: lockNow) } }
            Section("Appareils autorisés") { NavigationLink { AuthorizedDevicesView(store: store) } label: { LabeledContent("Appareils", value: "\(store.activeDevices.count) appareil\(store.activeDevices.count > 1 ? "s" : "")") } }
            Section("Application") { LabeledContent("Version", value: store.diagnostic.appVersion); LabeledContent("Build", value: store.diagnostic.build); LabeledContent("Environnement", value: store.diagnostic.environment); LabeledContent("Serveur", value: store.diagnostic.isBackendConfigured ? "Configuré" : "Non configuré"); NavigationLink("Diagnostic", destination: DiagnosticView(diagnostic: store.diagnostic)) }
            Section("Déconnexion") { Button("Se déconnecter", role: .destructive) { confirmsLogout = true } }
        }.navigationTitle("Profil").scrollContentBackground(.hidden).background(BotaplataColors.background).alert("Se déconnecter de Botaplata ?", isPresented: $confirmsLogout) { Button("Annuler", role: .cancel) {}; Button("Se déconnecter", role: .destructive) { Task { await logout() } } } message: { Text("Vous devrez vous authentifier à nouveau pour accéder à l'application.") }.overlay(alignment: .bottom) { if let message = store.message { Text(message).font(.footnote).padding().background(.thinMaterial, in: Capsule()).padding() } }
    }
}

struct AuthorizedDevicesView: View {
    @Bindable var store: ProfileStore
    @State private var pending: AuthorizedDevice?
    var body: some View { List { content }.navigationTitle("Appareils autorisés").refreshable { await store.refreshDevices() }.task { await store.refreshDevices() }.alert((pending?.isCurrent == true) ? "Révoquer cet iPhone ?" : "Révoquer cet appareil ?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) { Button("Annuler", role: .cancel) { pending = nil }; Button(pending?.isCurrent == true ? "Révoquer cet iPhone" : "Révoquer", role: .destructive) { if let device = pending { Task { await store.revoke(device) } }; pending = nil } } message: { Text(pending?.isCurrent == true ? "Vous serez immédiatement déconnecté et cet iPhone ne pourra plus utiliser sa session actuelle." : "Cet appareil ne pourra plus accéder à Botaplata avec sa session actuelle. Une nouvelle authentification sera nécessaire.") } }
    @ViewBuilder private var content: some View { switch store.devicesContent { case .idle, .loading: ProgressView("Chargement des appareils…"); case .failed(let message): VStack(alignment: .leading) { Text(message); Button("Réessayer") { Task { await store.refreshDevices() } } }; case .offline(let devices, let message): Section { Text(message).font(.footnote).foregroundStyle(.secondary) }; deviceSections(devices); case .refreshing(let devices), .loaded(let devices): deviceSections(devices) } }
    @ViewBuilder private func deviceSections(_ devices: [AuthorizedDevice]) -> some View { let current = devices.filter { $0.isCurrent }; let others = devices.filter { !$0.isCurrent }; if !current.isEmpty { Section("Cet appareil") { ForEach(current) { DeviceRow(device: $0, revoke: { pending = $0 }) } } }; if !others.isEmpty { Section("Autres appareils") { ForEach(others) { DeviceRow(device: $0, revoke: { pending = $0 }) } } } }
}

struct DeviceRow: View { let device: AuthorizedDevice; let revoke: (AuthorizedDevice) -> Void; var body: some View { VStack(alignment: .leading, spacing: 6) { Text(device.isCurrent ? "Cet iPhone" : device.name).font(.headline); Text([device.model, device.osVersion].filter { !$0.isEmpty }.joined(separator: " · ")).foregroundStyle(.secondary); Text(activityText).font(.caption).foregroundStyle(.secondary); if !device.isCurrent { Button("Révoquer l'accès", role: .destructive) { revoke(device) }.accessibilityLabel("Révoquer l'accès de \(device.name)") } }.accessibilityElement(children: .combine).accessibilityLabel("\(device.isCurrent ? "Cet iPhone" : device.name), \(device.model), \(device.isCurrent ? "appareil actuel, " : "")\(activityText)") }
    private var activityText: String { if device.isCurrent { return "Utilisé maintenant" }; let date = device.lastSeenAt ?? device.lastAuthenticatedAt; guard let date else { return "Jamais utilisé récemment" }; let rel = RelativeDateTimeFormatter(); rel.locale = Locale(identifier: "fr_FR"); rel.unitsStyle = .full; return "Dernière activité " + rel.localizedString(for: date, relativeTo: Date()) }
}

struct DiagnosticView: View { let diagnostic: ProfileDiagnostic; var body: some View { List { LabeledContent("Version app", value: diagnostic.appVersion); LabeledContent("Build", value: diagnostic.build); LabeledContent("Environnement", value: diagnostic.environment); LabeledContent("État d'authentification", value: diagnostic.authenticationState); LabeledContent("Backend", value: diagnostic.isBackendConfigured ? "configuré" : "non configuré"); LabeledContent("Biométrie", value: diagnostic.biometricState) }.navigationTitle("Diagnostic") } }

#Preview("Profil nominal") { NavigationStack { ProfileView(store: .preview(), lockNow: {}, logout: {}) } }
#Preview("Appareils") { NavigationStack { AuthorizedDevicesView(store: .preview()) } }
#Preview("Diagnostic") { DiagnosticView(diagnostic: ProfileStore.preview().diagnostic) }
