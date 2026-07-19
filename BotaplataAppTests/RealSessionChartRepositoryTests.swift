import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotaplataApp

final class RealSessionChartRepositoryTests: XCTestCase {
    override func tearDown() { URLProtocolStub.handler = nil; super.tearDown() }

    func testChartURLUsesBackendRawRangeAndOnlyOptionalQueryWhenProvided() async throws {
        var captured: URL?
        URLProtocolStub.handler = { request in
            captured = request.url
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ACCESS_TOKEN_SENTINEL")
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"session_id":"27","symbol":"SOLUSDC","display_symbol":"SOL/USDC","quote_asset":"USDC","range":"6h","timeframe":"5m","generated_at":"2026-07-18T12:00:00Z","data_source":"persisted_ohlcv","is_complete":true,"has_more":false,"next_before":null,"series":[],"markers":[],"levels":{"entry_price":null,"break_even_price":null,"minimum_profitable_exit_price":null,"trailing_stop_price":null}},"error":null,"meta":{"request_id":"req","server_time":"2026-07-18T12:00:01Z"},"warnings":[{"code":"chart_price_series_unavailable","message":"empty"}]}"#)
        }
        let repo = RealSessionChartRepository(client: client())
        _ = try await repo.fetchChart(sessionID: "27", range: .sixHours, before: nil, limit: nil, accessToken: "ACCESS_TOKEN_SENTINEL")
        let url = try XCTUnwrap(captured)
        XCTAssertEqual(url.path, "/api/mobile/v1/real/sessions/27/chart")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query, [URLQueryItem(name: "range", value: "6h")])
        XCTAssertFalse(url.absoluteString.contains("sixHours"))
        XCTAssertFalse(url.absoluteString.contains("24hours"))
    }

    private func client() -> APIClient { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [URLProtocolStub.self]; return APIClient(baseURL: URL(string: "https://botaplata.test")!, session: URLSession(configuration: c)) }
    private static func response(_ json: String, status: Int = 200) -> (HTTPURLResponse, Data) { (HTTPURLResponse(url: URL(string: "https://botaplata.test")!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8)) }
}
