import Foundation
import SwiftUI

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .dashboard
    var dashboardPath = NavigationPath()
    var sessionsPath = NavigationPath()
    var analysisPath = NavigationPath()
    var journalPath = NavigationPath()
    var profilePath = NavigationPath()
}
