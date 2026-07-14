import Foundation

struct DeviceRevocationResult: Codable, Equatable, Sendable { let revokedDeviceID: String; let currentDeviceRevoked: Bool; enum CodingKeys: String, CodingKey { case revokedDeviceID = "revoked_device_id", currentDeviceRevoked = "current_device_revoked" } }

struct RemoteAuthenticationRepository: AuthenticationRepository {
    let client: APIClientProtocol
    private let prefix = "api/mobile/v1/auth"
    init(client: APIClientProtocol) { self.client = client }
    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge { try map { try await client.send(APIEndpoint(method: .post, path: "\(prefix)/login"), body: LoginRequestDTO(username: username, password: password, device: device)) } }
    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession { try map { try await client.send(APIEndpoint(method: .post, path: "\(prefix)/verify-2fa"), body: TwoFactorVerifyRequestDTO(challengeID: challengeID, code: code)) } }
    func refresh(refreshToken: String, installationID: String) async throws -> AuthenticatedSession { try map { try await client.send(APIEndpoint(method: .post, path: "\(prefix)/refresh"), body: RefreshRequestDTO(refreshToken: refreshToken, installationID: installationID)) } }
    func logout(accessToken: String?) async { guard let accessToken else { return }; _ = try? await client.send(APIEndpoint(method: .post, path: "\(prefix)/logout", headers: HTTPHeaders.bearer(accessToken)), body: Optional<EmptyBody>.none) as EmptyResponse }
    func authorizedDevices(accessToken: String) async throws -> [AuthorizedDevice] { try map { try await client.send(APIEndpoint(method: .get, path: "\(prefix)/devices", headers: HTTPHeaders.bearer(accessToken)), body: Optional<EmptyBody>.none) } }
    func revokeDevice(id: String, accessToken: String) async throws -> DeviceRevocationResult { try map { try await client.send(APIEndpoint(method: .delete, path: "\(prefix)/devices/\(id)", headers: HTTPHeaders.bearer(accessToken)), body: Optional<EmptyBody>.none) } }
    private func map<T>(_ work: () async throws -> T) async throws -> T { do { return try await work() } catch APIClientError.business(let e, _) { throw e } catch APIClientError.network { throw AuthenticationError.offline } catch APIClientError.cancelled { throw CancellationError() } catch { throw AuthenticationError.serverUnavailable } }
}

struct RefreshRequestDTO: Codable, Equatable, Sendable { let refreshToken: String; let installationID: String; enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token", installationID = "installation_id" } }
