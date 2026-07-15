import SwiftUI

@main
struct BotaplataApp: App {
    @State private var appState: AppState
    @State private var router = AppRouter()
    @State private var authStore: AuthenticationStore
    @State private var activeSessionStore: ActiveSessionStore
    @State private var realSessionsStore: RealSessionsStore
    @State private var realSessionHistoryStore: RealSessionHistoryStore
    @State private var profileStore: ProfileStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        let demo = arguments.contains("--botaplata-demo-authenticated") || ProcessInfo.processInfo.environment["BOTAPLATA_DEBUG_DEMO"] == "1"
        let environment: AppEnvironment = arguments.contains("--botaplata-ui-tests") ? .uiTesting : (demo ? .debugPreview : .development)
        let state = AppState(sessionState: demo ? .authenticated : .unknown, environment: environment)
        let repository: AuthenticationRepository = arguments.contains("--botaplata-ui-tests") || demo ? MockAuthenticationRepository() : BotaplataApp.makeRepository(environment: environment)
        #else
        let environment: AppEnvironment = .production
        let state = AppState(sessionState: .unknown, environment: environment)
        let repository: AuthenticationRepository = BotaplataApp.makeRepository(environment: environment)
        #endif
        let tokenStore: TokenStoreProtocol = KeychainTokenStore()
        let auth = AuthenticationStore(repository: repository, tokenStore: tokenStore, appState: state)
        let snapshotRepository: RealActiveSnapshotRepository = arguments.contains("--botaplata-ui-tests") || demo ? MockRealActiveSnapshotRepository() : BotaplataApp.makeSnapshotRepository(environment: environment)
        let sessionsRepository: RealSessionsRepository = arguments.contains("--botaplata-ui-tests") || demo ? MockRealSessionsRepository() : BotaplataApp.makeSessionsRepository(environment: environment)
        let historyRepository: RealSessionHistoryRepository = arguments.contains("--botaplata-ui-tests") || demo ? MockRealSessionHistoryRepository() : BotaplataApp.makeHistoryRepository(environment: environment)
        _appState = State(initialValue: state)
        _authStore = State(initialValue: auth)
        _activeSessionStore = State(initialValue: ActiveSessionStore(repository: snapshotRepository, cache: FileActiveSessionCache(), authSession: auth.session, appState: state))
        _realSessionsStore = State(initialValue: RealSessionsStore(repository: sessionsRepository, cache: FileRealSessionsCache(), authSession: auth.session, appState: state))
        _realSessionHistoryStore = State(initialValue: RealSessionHistoryStore(repository: historyRepository, cache: FileRealSessionHistoryCache(), authSession: auth.session, appState: state))
        _profileStore = State(initialValue: ProfileStore(authSession: auth.session, appState: state, authenticator: LocalAuthenticationBiometricAuthenticator(), preferences: UserDefaultsSecurityPreferencesStore()))
    }

    static func makeRepository(environment: AppEnvironment) -> AuthenticationRepository {
        guard let baseURL = environment.baseURL else { return UnconfiguredAuthenticationRepository() }
        return RemoteAuthenticationRepository(client: APIClient(baseURL: baseURL))
    }

    static func makeSnapshotRepository(environment: AppEnvironment) -> RealActiveSnapshotRepository {
        guard let baseURL = environment.baseURL else { return UnconfiguredRealActiveSnapshotRepository() }
        return RemoteRealActiveSnapshotRepository(client: APIClient(baseURL: baseURL))
    }

    static func makeSessionsRepository(environment: AppEnvironment) -> RealSessionsRepository {
        guard let baseURL = environment.baseURL else { return UnconfiguredRealSessionsRepository() }
        return RemoteRealSessionsRepository(client: APIClient(baseURL: baseURL))
    }

    static func makeHistoryRepository(environment: AppEnvironment) -> RealSessionHistoryRepository {
        guard let baseURL = environment.baseURL else { return UnconfiguredRealSessionHistoryRepository() }
        return RemoteRealSessionHistoryRepository(client: APIClient(baseURL: baseURL))
    }

    var body: some Scene {
        WindowGroup { RootView().environment(appState).environment(router).environment(authStore).environment(activeSessionStore).environment(realSessionsStore).environment(realSessionHistoryStore).environment(profileStore).task { if appState.sessionState == .unknown { await authStore.restore() } } }
    }
}
