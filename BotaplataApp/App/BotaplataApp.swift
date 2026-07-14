import SwiftUI

@main
struct BotaplataApp: App {
    @State private var appState: AppState
    @State private var router = AppRouter()
    @State private var authStore: AuthenticationStore
    @State private var activeSessionStore: ActiveSessionStore

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
        _appState = State(initialValue: state)
        _authStore = State(initialValue: auth)
        _activeSessionStore = State(initialValue: ActiveSessionStore(repository: snapshotRepository, cache: FileActiveSessionCache(), authSession: auth.session, appState: state))
    }

    static func makeRepository(environment: AppEnvironment) -> AuthenticationRepository {
        guard let baseURL = environment.baseURL else { return UnconfiguredAuthenticationRepository() }
        return RemoteAuthenticationRepository(client: APIClient(baseURL: baseURL))
    }

    static func makeSnapshotRepository(environment: AppEnvironment) -> RealActiveSnapshotRepository {
        guard let baseURL = environment.baseURL else { return MockRealActiveSnapshotRepository(snapshot: RealActiveSnapshot(generatedAt: nil, activeSessionCount: 0, activeSession: nil, warnings: [], requestID: nil, serverTime: nil)) }
        return RemoteRealActiveSnapshotRepository(client: APIClient(baseURL: baseURL))
    }

    var body: some Scene {
        WindowGroup { RootView().environment(appState).environment(router).environment(authStore).environment(activeSessionStore).task { if appState.sessionState == .unknown { await authStore.restore() } } }
    }
}
