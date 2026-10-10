import Foundation
#if canImport(SwiftUI)
import Observation
#endif

typealias StrategyExplanationAuthorization = @Sendable (@escaping @Sendable (String) async throws -> StrategyExplanation) async throws -> StrategyExplanation

enum RealStrategyExplanationState: Sendable { case idle, loading, loaded, refreshing, offlineCached, empty, error(String) }

@MainActor
#if canImport(SwiftUI)
@Observable
#endif
final class RealStrategyExplanationStore {
    var state: RealStrategyExplanationState = .idle
    var sessionID: String?
    var explanation: StrategyExplanation?
    var isLoading = false
    var isRefreshing = false
    var error: String?
    var lastUpdatedAt: Date?
    var isOffline = false
    private let repository: RealStrategyExplanationRepository
    private let authorize: StrategyExplanationAuthorization
    private let onAuthenticationFailure: (AuthenticationError) -> Void
    private let ttl: TimeInterval
    private var cache: [String: (StrategyExplanation, Date)] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private var generations: [String: Int] = [:]

    init(repository: RealStrategyExplanationRepository, authorize: @escaping StrategyExplanationAuthorization, ttl: TimeInterval = 30, onAuthenticationFailure: @escaping (AuthenticationError) -> Void = { _ in }) {
        self.repository = repository; self.authorize = authorize; self.ttl = ttl; self.onAuthenticationFailure = onAuthenticationFailure
    }

    func load(sessionID id: String, reason: String = "sectionOpened", force: Bool = false) async {
        if sessionID != id {
            if let old = sessionID { cancel(sessionID: old) }
            sessionID = id
            explanation = cache[id]?.0
            lastUpdatedAt = cache[id]?.1
            isOffline = false
        }
        if let task = tasks[id] { await task.value; return }
        if !force, let cached = cache[id], Date().timeIntervalSince(cached.1) < ttl {
            apply(cached.0, at: cached.1, state: .loaded)
            return
        }
        let existing = cache[id]
        state = existing == nil ? .loading : .refreshing
        isLoading = existing == nil; isRefreshing = existing != nil; error = nil
        generations[id, default: 0] += 1
        let generation = generations[id]!
        let task = Task { [repository, authorize] in
            do {
                let value = try await authorize { token in
                    try await repository.fetchStrategyExplanation(sessionID: id, accessToken: token)
                }
                try Task.checkCancellation()
                guard self.sessionID == id, self.generations[id] == generation else { return }
                guard value.sessionID == id else { throw AuthenticationError.contractIncompatible }
                let fetchedAt = Date()
                self.cache[id] = (value, fetchedAt)
                self.apply(value, at: fetchedAt, state: .loaded)
            } catch is CancellationError { }
            catch {
                guard self.sessionID == id, self.generations[id] == generation, !Task.isCancelled else { return }
                if (error as? AuthenticationError) == .accessTokenExpired { self.onAuthenticationFailure(.accessTokenExpired) }
                else if (error as? AuthenticationError) == .deviceRevoked { self.onAuthenticationFailure(.deviceRevoked) }
                else { self.applyError(error, cached: existing) }
            }
        }
        tasks[id] = task
        await task.value
        if generations[id] == generation { tasks[id] = nil }
    }

    func refresh(sessionID id: String) async { await load(sessionID: id, reason: "manualRefresh", force: true) }
    func cancel(sessionID id: String) {
        tasks[id]?.cancel(); tasks[id] = nil; generations[id, default: 0] += 1
        if sessionID == id { isLoading = false; isRefreshing = false }
    }
    func purge() {
        for id in Array(tasks.keys) { cancel(sessionID: id) }
        cache.removeAll(); sessionID = nil; explanation = nil; state = .idle
        error = nil; lastUpdatedAt = nil; isLoading = false; isRefreshing = false; isOffline = false
    }
    private func apply(_ value: StrategyExplanation, at date: Date, state: RealStrategyExplanationState) {
        explanation = value
        self.state = value.conditions.isEmpty && value.indicators.indicators.isEmpty ? .empty : state
        isOffline = false; isLoading = false; isRefreshing = false; lastUpdatedAt = date
    }
    private func applyError(_ error: Error, cached: (StrategyExplanation, Date)?) {
        let text = (error as? AuthenticationError) == .offline ? "Erreur réseau" : "Analyse indisponible. Réessayez."
        self.error = text; isLoading = false; isRefreshing = false
        if let cached { explanation = cached.0; lastUpdatedAt = cached.1; isOffline = true; state = .offlineCached }
        else { explanation = nil; lastUpdatedAt = nil; isOffline = false; state = .error(text) }
    }
}
