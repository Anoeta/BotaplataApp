import Foundation

struct DeviceRevocationResult: Codable, Equatable, Sendable {
    let revokedDeviceID: String
    let currentDeviceRevoked: Bool

    enum CodingKeys: String, CodingKey {
        case revokedDeviceID = "revoked_device_id"
        case currentDeviceRevoked = "current_device_revoked"
    }
}

struct AuthorizedDevicesResponseDTO: Decodable, Sendable {
    let devices: [AuthorizedDevice]
    let currentDeviceID: String?
    enum CodingKeys: String, CodingKey { case devices; case currentDeviceID = "current_device_id" }
    var mappedDevices: [AuthorizedDevice] {
        guard let currentDeviceID else { return devices }
        return devices.map { device in
            AuthorizedDevice(id: device.id, name: device.name, model: device.model, osVersion: device.osVersion, appVersion: device.appVersion, locale: device.locale, createdAt: device.createdAt, lastSeenAt: device.lastSeenAt, lastAuthenticatedAt: device.lastAuthenticatedAt, isCurrent: device.isCurrent || device.id == currentDeviceID, isRevoked: device.isRevoked)
        }
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
            let response: AuthorizedDevicesResponseDTO = try await self.client.send(
                APIEndpoint(method: .get, path: "\(self.prefix)/devices", headers: HTTPHeaders.bearer(accessToken))
            )
            return response.mappedDevices
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
