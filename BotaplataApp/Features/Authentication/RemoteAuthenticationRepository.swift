import Foundation

struct DeviceRevocationResult: Codable, Equatable, Sendable {
    let revokedDeviceID: String
    let currentDeviceRevoked: Bool

    enum CodingKeys: String, CodingKey {
        case revokedDeviceID = "revoked_device_id"
        case currentDeviceRevoked = "current_device_revoked"
    }
}

struct RemoteAuthenticationRepository: AuthenticationRepository {
    let client: APIClientProtocol
    private let prefix = "api/mobile/v1/auth"

    init(client: APIClientProtocol) { self.client = client }

    func login(username: String, password: String, device: DeviceFingerprint) async throws -> TwoFactorChallenge {
        try await self.map {
            let response: TwoFactorChallenge = try await self.client.send(
                APIEndpoint(method: .post, path: "\(self.prefix)/login"),
                body: LoginRequestDTO(username: username, password: password, device: device)
            )
            return response
        }
    }

    func verifyTwoFactor(challengeID: String, code: String) async throws -> AuthenticatedSession {
        let dto: AuthenticationTokensDTO = try await self.map {
            try await self.client.send(
                APIEndpoint(method: .post, path: "\(self.prefix)/verify-2fa"),
                body: TwoFactorVerifyRequestDTO(challengeID: challengeID, code: code)
            )
        }
        return AuthenticatedSession(dto: dto)
    }

    func refresh(refreshToken: String, installationID: String) async throws -> AuthenticatedSession {
        let dto: AuthenticationTokensDTO = try await self.map {
            try await self.client.send(
                APIEndpoint(method: .post, path: "\(self.prefix)/refresh"),
                body: RefreshRequestDTO(refreshToken: refreshToken, installationID: installationID)
            )
        }
        return AuthenticatedSession(dto: dto)
    }

    func logout(accessToken: String?) async {
        guard let accessToken else { return }
        let _: EmptyResponse? = try? await self.client.send(
            APIEndpoint(method: .post, path: "\(self.prefix)/logout", headers: HTTPHeaders.bearer(accessToken))
        )
    }

    func authorizedDevices(accessToken: String) async throws -> [AuthorizedDevice] {
        try await self.map {
            let response: [AuthorizedDevice] = try await self.client.send(
                APIEndpoint(method: .get, path: "\(self.prefix)/devices", headers: HTTPHeaders.bearer(accessToken))
            )
            return response
        }
    }

    func revokeDevice(id: String, accessToken: String) async throws -> DeviceRevocationResult {
        try await self.map {
            let response: DeviceRevocationResult = try await self.client.send(
                APIEndpoint(method: .delete, path: "\(self.prefix)/devices/\(id)", headers: HTTPHeaders.bearer(accessToken))
            )
            return response
        }
    }

    private func map<T>(_ work: () async throws -> T) async throws -> T {
        do { return try await work() }
        catch APIClientError.business(let error, _) { throw error }
        catch APIClientError.network { throw AuthenticationError.offline }
        catch APIClientError.cancelled { throw CancellationError() }
        catch { throw AuthenticationError.serverUnavailable }
    }
}

struct RefreshRequestDTO: Codable, Equatable, Sendable {
    let refreshToken: String
    let installationID: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case installationID = "installation_id"
    }
}
