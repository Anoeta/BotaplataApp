import Foundation
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var dashboardPath = NavigationPath()
    var sessionsPath = NavigationPath()
    var journalPath = NavigationPath()
    var profilePath = NavigationPath()
}

enum AppTab: Hashable, CaseIterable, Sendable {
    case dashboard, sessions, journal, profile
    var title: String { switch self { case .dashboard: "Dashboard"; case .sessions: "Sessions"; case .journal: "Journal"; case .profile: "Profil" } }
    var symbol: String { switch self { case .dashboard: "gauge.with.dots.needle.67percent"; case .sessions: "list.bullet.rectangle.portrait"; case .journal: "book.pages"; case .profile: "person.crop.circle" } }
}
