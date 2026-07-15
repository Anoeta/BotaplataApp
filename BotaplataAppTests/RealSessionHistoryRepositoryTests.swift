import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotaplataApp

final class RealSessionHistoryRepositoryTests: XCTestCase {
    override func tearDown() { URLProtocolStub.handler = nil; super.tearDown() }
    func testFourHistoryRoutesUseGetBearerAndPagination() async throws {
        var paths: [String] = []
        URLProtocolStub.handler = { request in
            paths.append(request.url!.path); XCTAssertEqual(request.httpMethod, "GET"); XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ACCESS_TOKEN_SENTINEL"); XCTAssertFalse((request.value(forHTTPHeaderField: "Authorization") ?? "").contains("REFRESH_TOKEN_SENTINEL"))
            if request.url!.path.hasSuffix("/chart") { return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"session_id":"s1","symbol":"SOLUSDC","display_symbol":"SOL/USDC","quote_asset":"USDC","timeframe":"1m","points":[],"markers":[],"levels":{}},"error":null,"meta":{"request_id":"req_chart","server_time":"2026-07-14T10:00:00Z"},"warnings":[{"code":"chart_price_series_unavailable","message":"technical"}]}"#) }
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems; XCTAssertEqual(query?.first(where: { $0.name == "page" })?.value, "1"); XCTAssertEqual(query?.first(where: { $0.name == "page_size" })?.value, "50")
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"items":[],"pagination":{"page":1,"page_size":50,"total":0,"has_more":false}},"error":null,"meta":{"request_id":"req","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#)
        }
        let repo = RemoteRealSessionHistoryRepository(client: client())
        _ = try await repo.fetchTimeline(sessionID: "s1", page: 1, pageSize: 50, accessToken: "ACCESS_TOKEN_SENTINEL")
        _ = try await repo.fetchOrders(sessionID: "s1", page: 1, pageSize: 50, accessToken: "ACCESS_TOKEN_SENTINEL")
        _ = try await repo.fetchDecisions(sessionID: "s1", page: 1, pageSize: 50, accessToken: "ACCESS_TOKEN_SENTINEL")
        _ = try await repo.fetchChart(sessionID: "s1", accessToken: "ACCESS_TOKEN_SENTINEL")
        XCTAssertEqual(paths, ["/api/mobile/v1/real/sessions/s1/timeline", "/api/mobile/v1/real/sessions/s1/orders", "/api/mobile/v1/real/sessions/s1/decisions", "/api/mobile/v1/real/sessions/s1/chart"])
    }
    private func client() -> APIClient { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [URLProtocolStub.self]; return APIClient(baseURL: URL(string: "https://botaplata.test")!, session: URLSession(configuration: c)) }
    private static func response(_ json: String, status: Int = 200) -> (HTTPURLResponse, Data) { (HTTPURLResponse(url: URL(string: "https://botaplata.test")!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8)) }
}
