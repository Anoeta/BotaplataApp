import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotaplataApp

final class RealActiveSnapshotRepositoryTests: XCTestCase {
    override func tearDown() { URLProtocolStub.handler = nil; super.tearDown() }

    func testFetchUsesGetRouteBearerAccessTokenAndMapsEnvelopeMetadata() async throws {
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/mobile/v1/real/sessions/active-snapshot")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ACCESS_TOKEN_SENTINEL")
            XCTAssertFalse((request.value(forHTTPHeaderField: "Authorization") ?? "").contains("REFRESH_TOKEN_SENTINEL"))
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"generated_at":"2026-07-14T14:00:00Z","active_session_count":0,"active_session":null},"error":null,"meta":{"request_id":"req_snapshot","server_time":"2026-07-14T14:00:01Z"},"warnings":[{"code":"W_PARTIAL","message":"Partiel"}]}"#)
        }
        let repo = RemoteRealActiveSnapshotRepository(client: client())
        let snapshot = try await repo.fetchActiveSnapshot(accessToken: "ACCESS_TOKEN_SENTINEL")
        XCTAssertNil(snapshot.activeSession)
        XCTAssertEqual(snapshot.activeSessionCount, 0)
        XCTAssertEqual(snapshot.requestID, "req_snapshot")
        XCTAssertEqual(snapshot.warnings.first?.id, "W_PARTIAL")
        XCTAssertNotNil(snapshot.serverTime)
    }

    func testBackendAuthErrorsStayPrecise() async {
        for (code, expected) in [("AUTH_TOKEN_EXPIRED", AuthenticationError.accessTokenExpired), ("AUTH_DEVICE_REVOKED", .deviceRevoked), ("AUTH_USER_DISABLED", .userDisabled), ("PERMISSION_DENIED", .permissionDenied), ("SERVER_UNAVAILABLE", .serverUnavailable)] {
            URLProtocolStub.handler = { _ in Self.error(status: code == "PERMISSION_DENIED" ? 403 : 401, code: code) }
            await XCTAssertThrowsAuthentication(expected) { _ = try await RemoteRealActiveSnapshotRepository(client: self.client()).fetchActiveSnapshot(accessToken: "token") }
        }
    }

    private func client() -> APIClient { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [URLProtocolStub.self]; return APIClient(baseURL: URL(string: "https://botaplata.test")!, session: URLSession(configuration: c)) }
    private static func response(_ json: String, status: Int = 200) -> (HTTPURLResponse, Data) { (HTTPURLResponse(url: URL(string: "https://botaplata.test")!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8)) }
    private static func error(status: Int, code: String) -> (HTTPURLResponse, Data) { response("""
        {"ok":false,"version":"mobile_v1","data":null,"error":{"code":"\(code)","message":"sanitized","details":null,"retryable":false},"meta":{"request_id":"req_err","server_time":"2026-07-14T14:00:00Z"},"warnings":[]}
        """, status: status) }
}
