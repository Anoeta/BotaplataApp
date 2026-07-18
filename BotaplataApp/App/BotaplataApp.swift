import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct BotaplataApp: App {
    @State private var appState: AppState
    @State private var router = AppRouter()
    @State private var authStore: AuthenticationStore
    @State private var activeSessionStore: ActiveSessionStore
    @State private var realSessionsStore: RealSessionsStore
    @State private var realSessionHistoryStore: RealSessionHistoryStore
    @State private var realSessionChartStore: RealSessionChartStore
    @State private var profileStore: ProfileStore
    @State private var pushStore: PushNotificationsStore
    @StateObject private var pushBridge = PushNotificationEventBridge()
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(BotaplataAppDelegate.self) private var appDelegate
    #endif

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("--botaplata-ui-tests")
        #if DEBUG
        let isExplicitDemo = arguments.contains("--botaplata-demo-authenticated") || ProcessInfo.processInfo.environment["BOTAPLATA_DEBUG_DEMO"] == "1"
        let environment: AppEnvironment = isUITesting ? .uiTesting : (isExplicitDemo ? .debugPreview : .development)
        #else
        let isExplicitDemo = false
        let environment: AppEnvironment = .production
        #endif
        let usesFixtures = isUITesting || isExplicitDemo
        let state = AppState(sessionState: isExplicitDemo ? .authenticated : .unknown, environment: environment)
        let repository: AuthenticationRepository = usesFixtures ? MockAuthenticationRepository() : BotaplataApp.makeRepository(environment: environment)
        let tokenStore: TokenStoreProtocol = KeychainTokenStore()
        let auth = AuthenticationStore(repository: repository, tokenStore: tokenStore, appState: state)
        let snapshotRepository: RealActiveSnapshotRepository = usesFixtures ? MockRealActiveSnapshotRepository() : BotaplataApp.makeSnapshotRepository(environment: environment)
        let sessionsRepository: RealSessionsRepository = usesFixtures ? MockRealSessionsRepository() : BotaplataApp.makeSessionsRepository(environment: environment)
        let historyRepository: RealSessionHistoryRepository = usesFixtures ? MockRealSessionHistoryRepository() : BotaplataApp.makeHistoryRepository(environment: environment)
        let chartRepository: RealSessionChartRepositoryProtocol = usesFixtures ? MockRealSessionChartRepository() : BotaplataApp.makeChartRepository(environment: environment)
        let pushRepository: PushNotificationsRepository = usesFixtures ? MockPushNotificationsRepository() : BotaplataApp.makePushRepository(environment: environment)
        _appState = State(initialValue: state)
        _authStore = State(initialValue: auth)
        _activeSessionStore = State(initialValue: ActiveSessionStore(repository: snapshotRepository, cache: FileActiveSessionCache(), authSession: auth.session, appState: state))
        _realSessionsStore = State(initialValue: RealSessionsStore(repository: sessionsRepository, cache: FileRealSessionsCache(), authSession: auth.session, appState: state))
        _realSessionHistoryStore = State(initialValue: RealSessionHistoryStore(repository: historyRepository, cache: FileRealSessionHistoryCache(), authSession: auth.session, appState: state))
        _realSessionChartStore = State(initialValue: RealSessionChartStore(repository: chartRepository, authSession: auth.session))
        _profileStore = State(initialValue: ProfileStore(authSession: auth.session, appState: state, authenticator: LocalAuthenticationBiometricAuthenticator(), preferences: UserDefaultsSecurityPreferencesStore()))
        _pushStore = State(initialValue: PushNotificationsStore(repository: pushRepository, permissionManager: PushNotificationPermissionManager(), cache: FilePushNotificationsCache(), authSession: auth.session, appState: state))
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

    static func makeChartRepository(environment: AppEnvironment) -> RealSessionChartRepositoryProtocol {
        guard let baseURL = environment.baseURL else { return UnconfiguredRealSessionChartRepository() }
        return RealSessionChartRepository(client: APIClient(baseURL: baseURL))
    }

    static func makePushRepository(environment: AppEnvironment) -> PushNotificationsRepository {
        guard let baseURL = environment.baseURL else { return UnconfiguredPushNotificationsRepository() }
        return RemotePushNotificationsRepository(client: APIClient(baseURL: baseURL))
    }

    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.dark).environment(appState).environment(router).environment(authStore).environment(activeSessionStore).environment(realSessionsStore).environment(realSessionHistoryStore).environment(realSessionChartStore).environment(profileStore).environment(pushStore).task { BotaplataAppDelegate.bridge = pushBridge; pushBridge.onDeviceToken = { token in Task { await pushStore.registerDeviceToken(token) } }; pushBridge.onForeground = { Task { await pushStore.refreshAll() } }; pushBridge.onNotificationTap = { target, id in Task { await pushStore.handleNotificationTap(target: target, notificationID: id, router: router) } }; if appState.sessionState == .unknown { await authStore.restore() } } }
    }
}
