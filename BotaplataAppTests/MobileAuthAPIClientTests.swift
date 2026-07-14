import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import BotaplataApp

final class MobileAuthAPIClientTests: XCTestCase {
    override func tearDown() { URLProtocolStub.handler = nil; super.tearDown() }

    func testLoginRequestAndChallengeDecoding() async throws {
        let repo = RemoteAuthenticationRepository(client: makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/mobile/v1/auth/login")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
            let body = String(data: request.httpBodyStreamData(), encoding: .utf8) ?? ""
            XCTAssertTrue(body.contains("fixture-installation-id"))
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"challenge_id":"challenge-real","challenge_type":"totp","expires_at":"2026-07-14T10:00:00.123Z","attempts_remaining":5},"error":null,"meta":{"request_id":"req_login","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#)
        })
        let challenge = try await repo.login(username: "user", password: "sentinel-password", device: DeviceFingerprint(installationID: "fixture-installation-id", name: "iPhone", model: "iPhone", osVersion: "26.5", appVersion: "1.0", locale: "fr-FR"))
        XCTAssertEqual(challenge.id, "challenge-real")
    }

    func testVerifyRefreshLogoutAndDevices() async throws {
        var paths: [String] = []
        let repo = RemoteAuthenticationRepository(client: makeClient { request in
            paths.append(request.url!.path)
            if request.url!.path.contains("verify-2fa") { return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"access_token":"access-new","access_token_expires_at":"2026-07-14T10:15:00Z","refresh_token":"refresh-new","refresh_token_expires_at":"2026-08-14T10:00:00Z","token_type":"Bearer","device_id":"dev-1","user":{"id":"u1","display_name":"Botaplata","roles":["operator"],"permissions":["read"]}},"error":null,"meta":{"request_id":"req_2fa","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#) }
            if request.url!.path.contains("refresh") { XCTAssertTrue((String(data: request.httpBodyStreamData(), encoding: .utf8) ?? "").contains("installation_id")); return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"access_token":"access-rotated","access_token_expires_at":"2026-07-14T10:20:00Z","refresh_token":"refresh-rotated","refresh_token_expires_at":"2026-08-14T10:00:00Z","token_type":"Bearer","device_id":"dev-1","user":{"id":"u1","display_name":"Botaplata","roles":[],"permissions":[]}},"error":null,"meta":{"request_id":"req_refresh","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#) }
            if request.httpMethod == "GET" { XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-rotated"); return Self.response(#"{"ok":true,"version":"mobile_v1","data":[{"id":"dev-1","name":"iPhone","model":"iPhone","os_version":"26.5","app_version":"1.0","locale":"fr-FR","created_at":"2026-07-14T10:00:00Z","last_seen_at":null,"last_authenticated_at":"2026-07-14T10:00:00Z","is_current":true,"is_revoked":false}],"error":null,"meta":{"request_id":"req_devices","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#) }
            if request.httpMethod == "DELETE" { return Self.response(#"{"ok":true,"version":"mobile_v1","data":{"revoked_device_id":"dev-1","current_device_revoked":true},"error":null,"meta":{"request_id":"req_revoke","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#) }
            return Self.response(#"{"ok":true,"version":"mobile_v1","data":{},"error":null,"meta":{"request_id":"req_logout","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#)
        })
        let session = try await repo.verifyTwoFactor(challengeID: "challenge", code: "123456")
        XCTAssertEqual(session.deviceID, "dev-1")
        let refreshed = try await repo.refresh(refreshToken: session.refreshToken, installationID: "install-1")
        let devices = try await repo.authorizedDevices(accessToken: refreshed.accessToken)
        XCTAssertTrue(devices[0].isCurrent)
        let result = try await repo.revokeDevice(id: "dev-1", accessToken: refreshed.accessToken)
        await repo.logout(accessToken: refreshed.accessToken)
        XCTAssertTrue(result.currentDeviceRevoked)
        XCTAssertTrue(paths.contains("/api/mobile/v1/auth/logout"))
    }

    func testBackendErrorMappingAndSanitizedLogging() async throws {
        let repo = RemoteAuthenticationRepository(client: makeClient { _ in Self.response(#"{"ok":false,"version":"mobile_v1","data":null,"error":{"code":"AUTH_DEVICE_REVOKED","message":"revoked","details":null,"retryable":false},"meta":{"request_id":"req_err","server_time":"2026-07-14T10:00:00Z"},"warnings":[]}"#) })
        await XCTAssertThrowsAuthentication(.deviceRevoked) { _ = try await repo.refresh(refreshToken: "refresh", installationID: "install") }
        let redacted = SecureLogging.sanitized("Authorization: Bearer access password=p code=123456 refresh_token=r installation_id=i")
        XCTAssertFalse(redacted.contains("access")); XCTAssertFalse(redacted.contains("123456")); XCTAssertFalse(redacted.contains("refresh_token=r"))
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
        URLProtocolStub.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return APIClient(baseURL: URL(string: "https://botaplata.test")!, session: URLSession(configuration: config))
    }
    private static func response(_ json: String, status: Int = 200) -> (HTTPURLResponse, Data) { (HTTPURLResponse(url: URL(string: "https://botaplata.test")!, statusCode: status, httpVersion: nil, headerFields: nil)!, Data(json.utf8)) }
}

final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { do { let (response, data) = try Self.handler!(request); client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self) } catch { client?.urlProtocol(self, didFailWithError: error) } }
    override func stopLoading() {}
}

private extension URLRequest {
    func httpBodyStreamData() -> Data {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count > 0 { data.append(buffer, count: count) } else { break } }
        return data
    }
}
