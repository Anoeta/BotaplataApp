import Foundation

protocol RealSessionHistoryCache: Sendable { func load() async -> RealSessionHistoryCached?; func saveTimeline(sessionID: String, page: TimelinePage) async; func saveChart(sessionID: String, chart: SessionChart) async; func purge() async }
struct RealSessionHistoryCached: Codable, Sendable { var timelines: [String: TimelinePage]; var charts: [String: SessionChart]; var savedAt: Date }
struct FileRealSessionHistoryCache: RealSessionHistoryCache { private let url: URL; private let version = 1; init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory) { url = directory.appendingPathComponent("botaplata-real-session-history-cache-v1.json") }
    func load() async -> RealSessionHistoryCached? { do { let data = try Data(contentsOf: url); let box = try JSONDecoder().decode(Box.self, from: data); return box.version == version ? box.cache : nil } catch { return nil } }
    func saveTimeline(sessionID: String, page: TimelinePage) async { var c = await load() ?? RealSessionHistoryCached(timelines: [:], charts: [:], savedAt: Date()); c.timelines[sessionID] = TimelinePage(items: Array(page.items.prefix(50)), pagination: page.pagination, warnings: page.warnings, serverTime: page.serverTime); trim(&c); await save(c) }
    func saveChart(sessionID: String, chart: SessionChart) async { var c = await load() ?? RealSessionHistoryCached(timelines: [:], charts: [:], savedAt: Date()); c.charts[sessionID] = chart; trim(&c); await save(c) }
    func purge() async { try? FileManager.default.removeItem(at: url) }
    private func trim(_ c: inout RealSessionHistoryCached) { c.savedAt = Date(); while c.timelines.count > 5 { c.timelines.removeValue(forKey: c.timelines.keys.sorted().first!) }; while c.charts.count > 5 { c.charts.removeValue(forKey: c.charts.keys.sorted().first!) } }
    private func save(_ c: RealSessionHistoryCached) async { do { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(Box(version: version, cache: c)).write(to: url, options: [.atomic]) } catch {} }
    private struct Box: Codable { let version: Int; let cache: RealSessionHistoryCached }
}
