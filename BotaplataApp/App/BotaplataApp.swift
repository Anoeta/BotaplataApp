import SwiftUI

@main
struct BotaplataApp: App {
    @State private var appState = AppState.demo()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(router)
        }
    }
}
