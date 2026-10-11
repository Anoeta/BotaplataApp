import SwiftUI
import XCTest
@testable import BotaplataApp

@MainActor final class MidnightNavigationTests: XCTestCase {
    func testNotificationStillRoutesToSessionAnalysisWithFiveTabs() {
        let router = AppRouter()
        router.route(to: NotificationNavigationTarget(kind: .session, sessionID: "42", section: .analysis))
        XCTAssertEqual(router.selectedTab, .sessions)
        XCTAssertEqual(router.sessionsPath.count, 1)
        XCTAssertEqual(router.analysisPath.count, 0)
    }

    func testJournalNotificationPreservesExistingJournalRoute() {
        let router = AppRouter()
        router.route(to: NotificationNavigationTarget(kind: .session, sessionID: "28", section: .journal))
        XCTAssertEqual(router.selectedTab, .journal)
        XCTAssertEqual(router.journalPath.count, 1)
    }

    func testSwitchingTabsRetainsExistingStacks() {
        let router = AppRouter()
        router.sessionsPath.append(SessionRoute.detail(id: "28", section: .orders))
        router.selectedTab = .analysis
        router.selectedTab = .sessions
        XCTAssertEqual(router.sessionsPath.count, 1)
        XCTAssertEqual(router.analysisPath.count, 0)
    }
}
