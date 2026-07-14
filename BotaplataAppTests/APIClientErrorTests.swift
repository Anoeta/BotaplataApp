import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotaplataApp

final class APIClientErrorTests: XCTestCase {
    override func tearDown() { URLProtocolStub.handler = nil; super.tearDown() }

    func testNon2xxPreservesBackendBusinessCodes() async throws {
        for (status, code) in [(401, "AUTH_TOKEN_EXPIRED"), (401, "AUTH_DEVICE_REVOKED"), (401, "AUTH_REFRESH_REVOKED"), (403, "PERMISSION_DENIED"), (429, "RATE_LIMITED"), (503, "SERVER_UNAVAILABLE")] {
            URLProtocolStub.handler = { _ in Self.response(status: status, code: code) }
            let client = APIClient(baseURL: URL(string: "https://botaplata.test")!, session: URLSession(configuration: Self.config()))
            do {
                let _: EmptyResponse = try await client.send(APIEndpoint(method: .get, path: "/api/mobile/v1/test"), body: Optional<EmptyBody>.none)
                XCTFail("Expected backend error")
            } catch APIClientError.backend(let receivedStatus, let payload, let requestID) {
                XCTAssertEqual(receivedStatus, status)
                XCTAssertEqual(payload.code, code)
                XCTAssertEqual(payload.message, "sanitized")
                XCTAssertEqual(payload.retryable, status == 503 || status == 429)
                XCTAssertEqual(requestID, "req_\(code)")
            } catch { XCTFail("Unexpected error: \(error)") }
        }
    }

    private static func config() -> URLSessionConfiguration { let c = URLSessionConfiguration.ephemeral; c.protocolClasses = [URLProtocolStub.self]; return c }
    private static func response(status: Int, code: String) -> (HTTPURLResponse, Data) {
        let retryable = (status == 503 || status == 429) ? "true" : "false"
        let json = """
        {"ok":false,"version":"mobile_v1","data":null,"error":{"code":"\(code)","message":"sanitized","details":null,"retryable":\(retryable)},"meta":{"request_id":"req_\(code)","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}
        """
        return (HTTPURLResponse(url: URL(string: "https://botaplata.test")!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8))
    }
}
