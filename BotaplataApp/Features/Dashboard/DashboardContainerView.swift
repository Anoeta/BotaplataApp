import SwiftUI

struct DashboardContainerView: View {
    @State var store: ActiveSessionStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View { DashboardView(content: store.content, refresh: { await store.refresh() }).task { store.start() }.onChange(of: scenePhase) { _, phase in if phase == .background { store.enterBackground() } else if phase == .active { store.enterForeground() } } }
}
