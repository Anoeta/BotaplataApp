import XCTest
@testable import BotaplataApp

final class MobileV1ContractDecodingTests: XCTestCase {
    func testSessionsPageWaitingBuyContract() throws {
        let page = try envelope("real_sessions_page_waiting_buy", RealSessionsPageDTO.self).data!.mapped(warnings: [warning])
        XCTAssertEqual(page.items.first?.id, "real-session-001")
        XCTAssertEqual(page.items.first?.executionMode, .real)
        XCTAssertEqual(page.items.first?.isPositionOpen, false)
        XCTAssertNil(page.items.first?.unrealizedPnLQuote)
        XCTAssertEqual(page.warnings.first?.message, warning.message)
    }

    func testActiveSnapshotWaitingBuyContract() throws {
        let snapshot = try envelope("real_active_snapshot_waiting_buy", RealActiveSnapshotDTO.self).mapped(warnings: [warning], requestID: "req")
        let session = try XCTUnwrap(snapshot.activeSession)
        XCTAssertEqual(session.executionMode, .real)
        XCTAssertNil(session.position)
        XCTAssertNil(session.pnl?.gross)
        XCTAssertEqual(session.decision.title, "Entrée à confirmer")
        XCTAssertEqual(session.decision.score, Decimal(3))
        XCTAssertEqual(session.currentPrice?.value, Decimal(string: "79.24"))
        XCTAssertEqual(session.freshness.status, .fresh)
    }

    func testActiveSnapshotPositionOpenContract() throws {
        let session = try XCTUnwrap(envelope("real_active_snapshot_position_open", RealActiveSnapshotDTO.self).mapped().activeSession)
        XCTAssertNotNil(session.position)
        XCTAssertEqual(session.position?.quantity, Decimal(string: "12.5"))
        XCTAssertEqual(session.position?.averageExecutionPrice?.value, Decimal(string: "78.90"))
        XCTAssertEqual(session.position?.costBasisPrice?.value, Decimal(string: "79.04"))
        XCTAssertEqual(session.pnl?.netEstimated?.value, Decimal(string: "13.20"))
        XCTAssertEqual(session.feeAware.liquidityRole, "Maker")
    }

    func testOrderPendingContractDoesNotBecomeFilledOrPosition() throws {
        let session = try XCTUnwrap(envelope("real_session_detail_order_pending", RealSessionDetailDTO.self).data!.mapped().activeOrder)
        XCTAssertEqual(session.id, "KRK-123")
        XCTAssertEqual(session.status, .open)
        XCTAssertNotEqual(session.status, .filled)
        XCTAssertEqual(session.averageExecutionPrice?.value, Decimal(string: "78.95"))
        let detail = envelope("real_session_detail_order_pending", RealSessionDetailDTO.self).data!.mapped()
        XCTAssertNil(detail.position)
    }

    func testReconciliationContract() throws {
        let detail = envelope("real_session_detail_reconciliation", RealSessionDetailDTO.self).data!.mapped()
        XCTAssertEqual(detail.reconciliation?.title, "Vérification en cours")
        XCTAssertNotEqual(detail.activeOrder?.status, .rejected)
    }

    func testNoSensitiveModelNames() {
        let names = ["api_key", "secret", "access_token", "refresh_token", "password", "totp", "authorization"]
        let surface = String(describing: RealSessionDetailDTO.self) + String(describing: RealActiveSnapshotDTO.self) + String(describing: RealSessionSummaryDTO.self)
        for name in names { XCTAssertFalse(surface.localizedCaseInsensitiveContains(name)) }
    }

    private var warning: APIWarning { APIWarning(code: "monitoring_degraded", message: "La surveillance de cette session rencontre actuellement un problème.") }
    private func envelope<T: Decodable & Sendable>(_ name: String, _ type: T.Type) throws -> APIEnvelope<T> {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/MobileV1/\(name).json")
        return try JSONCoding.decoder.decode(APIEnvelope<T>.self, from: Data(contentsOf: url))
    }
}
