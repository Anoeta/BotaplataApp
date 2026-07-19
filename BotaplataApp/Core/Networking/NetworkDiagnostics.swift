import Foundation

nonisolated enum ResultCategory: String, Sendable { case success, timeout, connectionRefused, offline, decoding, http, cancelled, network, unknown }
nonisolated enum CacheStatus: String, Sendable { case notApplicable, hit, miss, stale, write }

struct NetworkDiagnosticEntry: Identifiable, Sendable {
    var id: String { requestID }
    let requestID: String
    let method: String
    let endpoint: String
    let feature: String
    let startedAt: Date
    let duration: TimeInterval
    let statusCode: Int?
    let result: ResultCategory
    let cacheStatus: CacheStatus
}

actor NetworkDiagnosticsStore {
    static let shared = NetworkDiagnosticsStore()
    private var entries: [NetworkDiagnosticEntry] = []
    private(set) var timeoutCount = 0
    private(set) var retryCount = 0

    func record(_ entry: NetworkDiagnosticEntry) {
        guard DiagnosticsConfiguration.keepsNetworkHistory else { return }
        entries.append(entry)
        if entries.count > 50 { entries.removeFirst(entries.count - 50) }
        if entry.result == .timeout { timeoutCount += 1 }
    }

    func recordRetry() { guard DiagnosticsConfiguration.keepsNetworkHistory else { return }; retryCount += 1 }
    func snapshot() -> [NetworkDiagnosticEntry] { entries }
    func reset() { entries.removeAll(); timeoutCount = 0; retryCount = 0 }
}
