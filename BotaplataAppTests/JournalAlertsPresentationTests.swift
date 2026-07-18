import XCTest
@testable import BotaplataApp

final class JournalAlertsPresentationTests: XCTestCase {
    func testJournalEventTypeMapsToCategoryAndWording() {
        XCTAssertEqual(JournalEventPresentation.make(from: event(.decisionRecorded)).category, .decisions)
        XCTAssertEqual(JournalEventPresentation.make(from: event(.buySubmitted)).category, .orders)
        XCTAssertEqual(JournalEventPresentation.make(from: event(.positionOpened)).category, .positions)
        XCTAssertEqual(JournalEventPresentation.make(from: event(.monitoringDegraded)).category, .system)
        XCTAssertEqual(JournalEventPresentation.make(from: event(.decisionRecorded)).title, "Décision recalculée")
    }

    func testOrderStatusesStayPedagogicallyDistinct() {
        XCTAssertNotEqual(JournalEventPresentation.make(from: event(.buySubmitted)).title, JournalEventPresentation.make(from: event(.buyFilled)).title)
        XCTAssertNotEqual(JournalEventPresentation.make(from: event(.sellSubmitted)).title, JournalEventPresentation.make(from: event(.sellFilled)).title)
        XCTAssertNotEqual(JournalEventPresentation.make(from: event(.reconciliationPending)).title, "Ordre refusé par Kraken")
    }

    func testSignalsDoNotBecomeConfirmedExecutions() {
        let signal = event(.decisionRecorded, title: "Signal BUY détecté", message: "Signal analysé sans ordre confirmé.")
        XCTAssertFalse(JournalEventPresentation.make(from: signal).title.lowercased().contains("confirmé"))
        XCTAssertFalse(JournalEventPresentation.make(from: signal).title.lowercased().contains("achat confirmé"))
    }

    func testJournalFiltersLoadedEventsLocally() {
        let events = [event(.decisionRecorded), event(.buySubmitted), event(.positionClosed), event(.sessionStopped)]
        XCTAssertEqual(JournalEventPresentation.filtered(events, filter: .decisions, query: "").map(\.type), [.decisionRecorded])
        XCTAssertEqual(JournalEventPresentation.filtered(events, filter: .orders, query: "").map(\.type), [.buySubmitted])
        XCTAssertEqual(JournalEventPresentation.filtered(events, filter: .positions, query: "").map(\.type), [.positionClosed])
        XCTAssertEqual(JournalEventPresentation.filtered(events, filter: .system, query: "").map(\.type), [.sessionStopped])
    }

    func testAlertReadSeverityAndFilters() {
        let info = alert(id: "i", severity: .info, read: true, sessionID: nil)
        let warning = alert(id: "w", severity: .warning, read: false, sessionID: "s1")
        let critical = alert(id: "c", severity: .critical, read: false, sessionID: "s1")
        XCTAssertEqual(AlertPresentation.make(from: info).severityLabel, "Information")
        XCTAssertEqual(AlertPresentation.make(from: warning).severityLabel, "Attention")
        XCTAssertEqual(AlertPresentation.make(from: critical).severityLabel, "Critique")
        XCTAssertEqual(AlertPresentation.filtered([info, warning, critical], filter: .unread).map(\.id), ["w", "c"])
        XCTAssertEqual(AlertPresentation.filtered([info, warning, critical], filter: .critical).map(\.id), ["c"])
        XCTAssertEqual(AlertPresentation.filtered([info, warning, critical], filter: .sessions).map(\.id), ["w", "c"])
        XCTAssertEqual(AlertPresentation.filtered([info, warning, critical], filter: .system).map(\.id), ["i"])
    }

    func testUnreadSummaryIsGlobalSourceOfTruthNotPageCount() {
        let summary = RealNotificationSummary(unreadCount: 12, latestCreatedAt: nil)
        XCTAssertEqual(summary.unreadCount, 12)
        XCTAssertNotEqual(summary.unreadCount, [alert(id: "one", read: false)].count)
    }

    func testDestinationSessionRouteAndMissingDestination() {
        let target = NotificationNavigationTarget(kind: .session, sessionID: "s1", section: .journal)
        XCTAssertEqual(SessionRoute.detail(id: "s1", section: target.section), .detail(id: "s1", section: .journal))
        XCTAssertFalse(AlertPresentation.make(from: alert(id: "none", sessionID: nil, target: nil)).hasDestination)
    }

    private func event(_ type: TimelineEventType, title: String = "Titre", message: String = "Message") -> TimelineEvent {
        TimelineEvent(id: UUID().uuidString, occurredAt: Date(), type: type, severity: .info, title: title, message: message, relatedOrderID: nil, relatedPositionID: nil, money: nil)
    }

    private func alert(id: String, severity: NotificationSeverity = .info, read: Bool = false, sessionID: String? = "s1", target: NotificationNavigationTarget? = NotificationNavigationTarget(kind: .session, sessionID: "s1", section: .journal)) -> RealNotificationItem {
        RealNotificationItem(id: id, eventType: "real_monitoring_degraded", severity: severity, title: "Surveillance", message: "Message", createdAt: Date(), isRead: read, sessionID: sessionID, symbol: sessionID == nil ? nil : "SOL/USDC", provider: sessionID == nil ? nil : "kraken", navigationTarget: target, money: nil)
    }
}
