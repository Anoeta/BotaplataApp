import Foundation

actor AuthenticationSession {
    private let repository: AuthenticationRepository
    private let tokenStore: TokenStoreProtocol
    private var session: AuthenticatedSession?
    private var refreshTask: Task<AuthenticatedSession, Error>?
    init(repository: AuthenticationRepository, tokenStore: TokenStoreProtocol) { self.repository = repository; self.tokenStore = tokenStore }
    var accessToken: String? { session?.accessToken }
    var user: AuthenticatedUser? { session?.user }
    var device: AuthorizedDevice? { session?.device }
    func apply(_ newSession: AuthenticatedSession) async throws { session = newSession; try await tokenStore.saveRefreshToken(newSession.refreshToken); try await tokenStore.saveDeviceID(newSession.device.id) }
    func restore() async throws -> AuthenticatedSession? { guard let token = try await tokenStore.readRefreshToken() else { return nil }; let restored = try await repository.restoreSession(refreshToken: token); try await apply(restored); return restored }
    func refresh() async throws -> AuthenticatedSession {
        if let refreshTask { return try await refreshTask.value }
        let task = Task<AuthenticatedSession, Error> { [repository, tokenStore] in guard let token = try await tokenStore.readRefreshToken() else { throw AuthenticationError.refreshRevoked }; return try await repository.refresh(refreshToken: token) }
        refreshTask = task
        do { let refreshed = try await task.value; try await apply(refreshed); refreshTask = nil; return refreshed } catch { refreshTask = nil; if matchesPurge(error) { try? await purgeLocal() }; throw error }
    }
    func logout() async { let token = try? await tokenStore.readRefreshToken(); await repository.logout(refreshToken: token ?? nil); try? await purgeLocal() }
    func purgeLocal() async throws { session = nil; try await tokenStore.purgeSession() }
    private func matchesPurge(_ error: Error) -> Bool { (error as? AuthenticationError) == .refreshRevoked || (error as? AuthenticationError) == .deviceRevoked }
}
