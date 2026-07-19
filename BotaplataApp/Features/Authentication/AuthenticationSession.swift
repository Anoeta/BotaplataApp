import Foundation
import OSLog

actor AuthenticationSession {
    private let repository: AuthenticationRepository
    private let tokenStore: TokenStoreProtocol
    private var session: AuthenticatedSession?
    private var refreshTask: Task<AuthenticatedSession, Error>?
    private var replayInProgress = false
    init(repository: AuthenticationRepository, tokenStore: TokenStoreProtocol) { self.repository = repository; self.tokenStore = tokenStore }
    var accessToken: String? { session?.accessToken }
    func validAccessTokenRefreshingIfNeeded() async throws -> String {
        if let token = session?.accessToken { return token }
        return try await refresh().accessToken
    }
    var user: AuthenticatedUser? { session?.user }
    var deviceID: String? { session?.deviceID }
    func apply(_ newSession: AuthenticatedSession) async throws { session = newSession; try await tokenStore.saveRefreshToken(newSession.refreshToken); try await tokenStore.saveDeviceID(newSession.deviceID) }
    func restore() async throws -> AuthenticatedSession? {
        let signpost = BotaplataSignpost.begin("auth restore")
        defer { BotaplataSignpost.end("auth restore", id: signpost) }
        guard try await tokenStore.readRefreshToken() != nil else {
            BotaplataLog.auth.info("auth restore skipped reason=noRefreshToken")
            return nil
        }
        BotaplataLog.auth.info("auth restore started reason=storedRefreshToken")
        return try await refresh()
    }
    func refresh() async throws -> AuthenticatedSession {
        if let refreshTask {
            BotaplataLog.auth.info("refresh joined existing task")
            return try await refreshTask.value
        }
        BotaplataLog.auth.info("refresh started")
        let task = Task<AuthenticatedSession, Error> { [repository, tokenStore] in
            let signpost = BotaplataSignpost.begin("refresh token")
            defer { BotaplataSignpost.end("refresh token", id: signpost) }
            guard let token = try await tokenStore.readRefreshToken() else { throw AuthenticationError.refreshRevoked }
            let installationID = try await tokenStore.installationID()
            return try await repository.refresh(refreshToken: token, installationID: installationID)
        }
        refreshTask = task
        do { let refreshed = try await task.value; try await apply(refreshed); refreshTask = nil; BotaplataLog.auth.info("refresh succeeded"); return refreshed } catch { refreshTask = nil; BotaplataLog.auth.error("refresh failed category=\(String(describing: error), privacy: .public)"); if matchesPurge(error) { try? await purgeLocal() }; throw error }
    }
    func logout() async { await repository.logout(accessToken: session?.accessToken); try? await purgeLocal() }
    func authorizedDevices() async throws -> [AuthorizedDevice] {
        try await withAccessTokenReplay { token in try await repository.authorizedDevices(accessToken: token) }
    }
    func revokeDevice(id: String) async throws -> DeviceRevocationResult {
        let result = try await withAccessTokenReplay { token in try await repository.revokeDevice(id: id, accessToken: token) }
        if result.currentDeviceRevoked { try await purgeLocal() }
        return result
    }
    func withAccessTokenReplay<T>(_ work: (String) async throws -> T) async throws -> T {
        let token = try await validAccessTokenRefreshingIfNeeded()
        do { return try await work(token) }
        catch AuthenticationError.accessTokenExpired {
            guard !replayInProgress else { BotaplataLog.auth.error("refresh replay skipped reason=loopGuard"); throw AuthenticationError.accessTokenExpired }
            replayInProgress = true
            defer { replayInProgress = false }
            BotaplataLog.auth.info("refresh replay count=1")
            await NetworkDiagnosticsStore.shared.recordRetry()
            let replayToken = try await refresh().accessToken
            do { return try await work(replayToken) }
            catch AuthenticationError.accessTokenExpired { try? await purgeLocal(); throw AuthenticationError.accessTokenExpired }
        }
    }
    func purgeLocal() async throws { session = nil; try await tokenStore.purgeSession() }
    private func matchesPurge(_ error: Error) -> Bool { [AuthenticationError.refreshRevoked, .refreshReuseDetected, .deviceRevoked, .accessTokenExpired].contains(error as? AuthenticationError) }
}
