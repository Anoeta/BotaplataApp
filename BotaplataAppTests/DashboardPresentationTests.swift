import XCTest
@testable import BotaplataApp

final class DashboardPresentationTests: XCTestCase {
    func testLifecycleWordingDoesNotConfirmPendingBuy() {
        XCTAssertEqual(DashboardPresentation.heroTitle(PreviewFixtures.waitingBuyFill), "Ordre d'achat en attente.")
        XCTAssertEqual(DashboardPresentation.orderStatusText(.reconciliationRequired), "Vérification en cours")
        XCTAssertEqual(DashboardPresentation.decisionBadgeText(.waitingSellFill), "Vente en attente")
    }

    func testMonitoringAndFreshnessWordingArePedagogical() {
        XCTAssertEqual(DashboardPresentation.monitoringText(.healthy), "Fonctionne normalement")
        XCTAssertEqual(DashboardPresentation.monitoringText(.degraded), "À surveiller")
        XCTAssertEqual(DashboardPresentation.freshnessText(DataFreshness(status: .stale, updatedAt: nil, source: .backend)), "Données anciennes")
    }

    func testPositionVisibilityRequiresPositiveBackendQuantity() {
        XCTAssertFalse(DashboardPresentation.shouldShowPosition(nil))
        XCTAssertFalse(DashboardPresentation.shouldShowPosition(OpenPosition(pair: "SOL/USDC", quantity: 0, averageExecutionPrice: nil, costBasisPrice: nil)))
        XCTAssertTrue(DashboardPresentation.shouldShowPosition(OpenPosition(pair: "SOL/USDC", quantity: 1, averageExecutionPrice: nil, costBasisPrice: nil)))
    }
}
