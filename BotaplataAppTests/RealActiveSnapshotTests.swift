import XCTest
@testable import BotaplataApp

final class RealActiveSnapshotTests: XCTestCase {
    func testDecimalStringParsingAndInvalidDoesNotBecomeZero() throws {
        struct Box: Decodable { let v: DecimalString? }
        XCTAssertEqual(try JSONDecoder().decode(Box.self, from: #"{"v":"10.29071263"}"#.data(using: .utf8)!).v?.value, Decimal(string: "10.29071263"))
        XCTAssertEqual(try JSONDecoder().decode(Box.self, from: #"{"v":"-3.52"}"#.data(using: .utf8)!).v?.value, Decimal(string: "-3.52"))
        XCTAssertNil(try JSONDecoder().decode(Box.self, from: #"{"v":null}"#.data(using: .utf8)!).v)
        XCTAssertThrowsError(try JSONDecoder().decode(Box.self, from: #"{"v":"not-a-number"}"#.data(using: .utf8)!))
    }
    func testLifecycleMappings() {
        XCTAssertEqual(SessionLifecycleState(backend: "waiting_buy"), .waitingBuy)
        XCTAssertEqual(SessionLifecycleState(backend: "waiting_buy_fill"), .waitingBuyFill)
        XCTAssertEqual(SessionLifecycleState(backend: "waiting_sell"), .waitingSell)
        XCTAssertEqual(SessionLifecycleState(backend: "waiting_sell_fill"), .waitingSellFill)
        XCTAssertEqual(SessionLifecycleState(backend: "reconciliation_pending"), .reconciliationPending)
    }
    func testNoActiveSessionStaysNilAndFeeAwarePartialStaysNil() throws {
        let json = #"{"generated_at":"2026-07-14T14:00:00Z","active_session_count":0,"active_session":null}"#.data(using: .utf8)!
        let dto = try JSONCoding.decoder.decode(RealActiveSnapshotDTO.self, from: json)
        let mapped = dto.mapped()
        XCTAssertNil(mapped.activeSession)
        XCTAssertEqual(mapped.activeSessionCount, 0)
        let fee = RealFeeAwareDTO(executionPrice: DecimalString(Decimal(1)), costBasisPrice: nil, buyFeeQuote: nil, buyFeeRateEffective: nil, buyFeeAsset: nil, estimatedSellFeeQuote: nil, estimatedSellFeeRate: nil, estimatedSellFeeSource: nil, liquidityRole: "unknown", liquidityRoleLabel: nil, breakEvenPrice: nil, minimumProfitableExitPrice: nil, minimumNetProfitRate: nil, estimatedSlippageRate: nil, grossCurrentValueQuote: nil, unrealizedPnlGrossQuote: nil, unrealizedPnlNetEstimatedQuote: nil, totalCycleFeesEstimatedQuote: nil).mapped(currency: "USDC")
        XCTAssertNil(fee.breakEvenPrice)
        XCTAssertEqual(fee.liquidityRole, "unknown")
    }
    func testWaitingBuyFillDoesNotCreatePositionAndReconciliationIsNotRejected() throws {
        let json = #"{"id":"s","provider":"kraken","execution_mode":"real","symbol":"SOLUSDC","display_symbol":"SOL/USDC","status":"active","lifecycle_state":"waiting_buy_fill","monitoring":{"health":"healthy"},"position":null,"active_order":{"id":"o","side":"BUY","order_type":"LIMIT","status":"open"}}"#.data(using: .utf8)!
        let session = try JSONCoding.decoder.decode(RealSessionDetailDTO.self, from: json).mapped()
        XCTAssertEqual(session.lifecycle, .waitingBuyFill)
        XCTAssertNil(session.position)
        XCTAssertEqual(OrderStatus(backend: "reconciliation_required"), .reconciliationRequired)
        XCTAssertNotEqual(SessionLifecycleState(backend: "reconciliation_pending"), .unknown)
    }
    func testDegradedMonitoringMessageIsNotNormal() {
        XCTAssertEqual(DashboardPresentation.globalMessage(health: .degraded), "La surveillance rencontre actuellement un problème.")
    }
}
