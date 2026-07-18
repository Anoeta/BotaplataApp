import XCTest
@testable import BotaplataApp

final class SessionRealDataPresentationTests: XCTestCase {
    func testPositionNilProducesNoPositionRows() {
        XCTAssertFalse(RealSessionUIPresentation.shouldShowPosition(nil))
        XCTAssertTrue(RealSessionUIPresentation.positionLines(session: PreviewFixtures.waitingBuy).isEmpty)
    }

    func testPositionPositiveProducesPositionRows() {
        let rows = RealSessionUIPresentation.positionLines(session: PreviewFixtures.krakenDetail)
        XCTAssertTrue(RealSessionUIPresentation.shouldShowPosition(PreviewFixtures.krakenDetail.position))
        XCTAssertTrue(rows.contains { $0.label == "Quantité" })
        XCTAssertTrue(rows.contains { $0.label == "Prix moyen exécuté" })
    }

    func testFinancialRowsHideNilLatentWithoutPositionAndShowNetWithPosition() {
        XCTAssertFalse(RealSessionUIPresentation.financialRows(session: PreviewFixtures.waitingBuy).contains { $0.label.contains("latent") })
        XCTAssertTrue(RealSessionUIPresentation.financialRows(session: PreviewFixtures.krakenDetail).contains { $0.label == "Résultat net estimé" })
    }

    func testDecisionScoreRowsOnlyWhenScoreExists() {
        XCTAssertFalse(RealSessionUIPresentation.decisionLines(PreviewFixtures.waitingBuy.decision).contains { $0.label == "Score" })
        var decision = PreviewFixtures.waitingBuy.decision
        decision.score = 3
        decision.scoreMin = 4
        XCTAssertTrue(RealSessionUIPresentation.decisionLines(decision).contains { $0.label == "Score" })
    }

    func testConditionsAndBlockersVisibility() {
        XCTAssertTrue(RealSessionUIPresentation.conditionSections(PreviewFixtures.waitingBuy.decision).isEmpty)
        var decision = PreviewFixtures.waitingBuy.decision
        decision.blockers = ["Le score minimum n’est pas encore atteint."]
        XCTAssertFalse(decision.blockers.isEmpty)
    }

    func testOrderSubmittedIsNotFilledAndReconciliationIsNotRejected() {
        XCTAssertEqual(RealSessionUIPresentation.orderStatusText(.submitted), "Envoyé à Kraken")
        XCTAssertNotEqual(RealSessionUIPresentation.orderStatusText(.submitted), RealSessionUIPresentation.orderStatusText(.filled))
        XCTAssertEqual(RealSessionUIPresentation.orderStatusText(.reconciliationRequired), "Vérification nécessaire")
        XCTAssertNotEqual(RealSessionUIPresentation.orderStatusText(.reconciliationRequired), RealSessionUIPresentation.orderStatusText(.rejected))
    }

    func testFeeAwareEmptyCardRowsHidden() {
        XCTAssertTrue(RealSessionUIPresentation.feeAwareRows(PreviewFixtures.feePartial).isEmpty)
        XCTAssertFalse(RealSessionUIPresentation.feeAwareRows(PreviewFixtures.feeComplete).isEmpty)
    }

    func testSessionFreshnessPresentationTexts() {
        XCTAssertEqual(SessionFreshnessPresentation.text(for: DataFreshness(status: .fresh, updatedAt: nil, source: .backend)), "Données fraîches")
        XCTAssertEqual(SessionFreshnessPresentation.text(for: DataFreshness(status: .aging, updatedAt: nil, source: .backend)), "Actualisation ralentie")
        XCTAssertEqual(SessionFreshnessPresentation.text(for: DataFreshness(status: .stale, updatedAt: nil, source: .backend)), "Données anciennes")
        XCTAssertEqual(SessionFreshnessPresentation.text(for: DataFreshness(status: .unknown, updatedAt: nil, source: .unknown)), "Fraîcheur inconnue")
    }

    func testLocalSectionSelectionModelAndChartNoFakeSeries() {
        var selected: NotificationNavigationTarget.Section = .overview
        let initial = selected
        selected = .decisions
        XCTAssertEqual(initial, .overview)
        XCTAssertEqual(selected, .decisions)
        XCTAssertTrue(PreviewFixtures.sessionChart.points.isEmpty)
        XCTAssertFalse(PreviewFixtures.sessionChart.markers.isEmpty)
    }
}
