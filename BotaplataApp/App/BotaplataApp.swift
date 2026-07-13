import SwiftUI

@main
struct BotaplataApp: App {
    @State private var appState: AppState
    @State private var router = AppRouter()
    @State private var authStore: AuthenticationStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        let demo = arguments.contains("--botaplata-demo-authenticated") || ProcessInfo.processInfo.environment["BOTAPLATA_DEBUG_DEMO"] == "1"
        let state = AppState(sessionState: demo ? .authenticated : .unknown, environment: demo ? .debugPreview : .normal)
        let repository: AuthenticationRepository = arguments.contains("--botaplata-ui-tests") || demo ? MockAuthenticationRepository() : UnconfiguredAuthenticationRepository()
        #else
        let state = AppState(sessionState: .unknown, environment: .normal)
        let repository: AuthenticationRepository = UnconfiguredAuthenticationRepository()
        #endif
        let tokenStore: TokenStoreProtocol = KeychainTokenStore()
        _appState = State(initialValue: state)
        _authStore = State(initialValue: AuthenticationStore(repository: repository, tokenStore: tokenStore, appState: state))
    }

    var body: some Scene {
        WindowGroup { RootView().environment(appState).environment(router).environment(authStore).task { if appState.sessionState == .unknown { await authStore.restore() } } }
    }
}
