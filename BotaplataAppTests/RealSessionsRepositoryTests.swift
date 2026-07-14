import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotaplataApp

final class RealSessionsRepositoryTests: XCTestCase {
    override func tearDown() { URLProtocolStub.handler = nil; super.tearDown() }
    func testFetchSessionsUsesExactRouteQueryAndBearer() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/mobile/v1/real/sessions")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value, "1")
            XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page_size" })?.value, "25")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ACCESS_TOKEN_SENTINEL")
            XCTAssertFalse((request.value(forHTTPHeaderField: "Authorization") ?? "").contains("REFRESH_TOKEN_SENTINEL"))
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"items":[{"id":"s1","provider":"kraken","provider_label":"Kraken","execution_mode":"spot_production","symbol":"SOLUSDC","display_symbol":"SOL/USDC","status":"running","lifecycle_state":"waiting_sell","monitoring":{"health":"degraded","last_success_at":null,"last_error_at":null,"consecutive_errors":770},"freshness":{"status":"fresh","updated_at":"2026-07-14T14:00:00Z"},"position":{"is_open":true,"status":"open","base_qty":"12.5","current_price":"79.24"},"active_order":{"side":"SELL","status":"open","exchange_order_id":"ord_1"},"strategy":{"key":"default","version":"1","display_name":"Default"},"started_at":"2026-07-14T13:00:00Z","stopped_at":null,"updated_at":"2026-07-14T14:00:00Z","unrealized_pnl_quote":"3.52","realized_pnl_net_quote":null}],"pagination":{"page":1,"page_size":25,"total":1,"has_more":false}},"error":null,"meta":{"request_id":"req","server_time":"2026-07-14T14:00:01Z"},"warnings":[{"code":"monitoring_degraded","message":"Surveillance perturbée"}]}"#)
        }
        let page = try await RemoteRealSessionsRepository(client: client()).fetchSessions(page: 1, pageSize: 25, accessToken: "ACCESS_TOKEN_SENTINEL")
        XCTAssertEqual(page.items.first?.pair, "SOL/USDC")
        XCTAssertEqual(page.items.first?.runtimeHealth, .degraded)
        XCTAssertEqual(page.items.first?.realizedPnLNetQuote?.value, nil)
        XCTAssertEqual(page.items.first?.unrealizedPnLQuote?.value, Decimal(string: "3.52"))
        XCTAssertEqual(page.pagination.hasMore, false)
        XCTAssertEqual(page.warnings.first?.title, "Surveillance perturbée")
    }
    func testFetchDetailUsesExactRouteAndPreservesNullPnL() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/mobile/v1/real/sessions/session-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ACCESS_TOKEN_SENTINEL")
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"id":"session-123","name":"SOL","status":"running","provider":"kraken","provider_label":"Kraken","execution_mode":"spot_production","symbol":"SOLUSDC","display_symbol":"SOL/USDC","quote_asset":"USDC","base_asset":"SOL","strategy_key":"default","strategy_version":"1","strategy_display_name":"Default","started_at":"2026-07-14T13:00:00Z","updated_at":"2026-07-14T14:00:00Z","lifecycle_state":"reconciliation_pending","monitoring":{"health":"healthy","consecutive_errors":0},"freshness":{"status":"stale","updated_at":"2026-07-14T13:59:00Z"},"market":{"current_price":"79.24","quote_asset":"USDC","updated_at":"2026-07-14T14:00:00Z"},"decision":{"title":"Position ouverte","detail":"Botaplata surveille les conditions de sortie."},"position":{"base_qty":"12.5","average_execution_price":"78.90","cost_basis_price":"79.04"},"active_order":{"id":"o1","side":"SELL","status":"submitted"},"reconciliation":{"state":"reconciliation_pending","required":true},"fee_aware":{"cost_basis_price":"79.04","break_even_price":"79.36","unrealized_pnl_net_estimated_quote":"2.54"},"pnl":{"unrealized_pnl_quote":"3.40","realized_pnl_net_quote":null}},"error":null,"meta":{"request_id":"req","server_time":"2026-07-14T14:00:01Z"},"warnings":[]}"#)
        }
        let detail = try await RemoteRealSessionsRepository(client: client()).fetchSessionDetail(id: "session-123", accessToken: "ACCESS_TOKEN_SENTINEL")
        XCTAssertEqual(detail.lifecycle, .reconciliationPending)
        XCTAssertEqual(detail.activeOrder?.status, .submitted)
        XCTAssertNotNil(detail.reconciliation)
        XCTAssertEqual(detail.pnl?.gross?.value, Decimal(string: "3.40"))
        XCTAssertNil(detail.pnl?.realizedNet?.value)
        XCTAssertEqual(detail.feeAware.breakEvenPrice?.value, Decimal(string: "79.36"))
    }
    private func client() -> APIClient { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [URLProtocolStub.self]; return APIClient(baseURL: URL(string: "https://botaplata.test")!, session: URLSession(configuration: c)) }
    private static func response(_ json: String, status: Int = 200) -> (HTTPURLResponse, Data) { (HTTPURLResponse(url: URL(string: "https://botaplata.test")!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8)) }
}
