import Foundation

protocol RealSessionsCache: Sendable { func load() async -> RealSessionsCachedPage?; func save(_ page: RealSessionsCachedPage) async; func purge() async }
struct RealSessionsCachedPage: Equatable, Sendable, Codable { let items: [SessionSummary]; let pagination: RealSessionsPagination; let savedAt: Date }
struct FileRealSessionsCache: RealSessionsCache { private let url: URL; private let version = 1; init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory) { url = directory.appendingPathComponent("botaplata-real-sessions-cache-v1.json") }
    func load() async -> RealSessionsCachedPage? { do { let data = try Data(contentsOf: url); let box = try JSONDecoder().decode(Box.self, from: data); return box.version == version ? box.page : nil } catch { return nil } }
    func save(_ page: RealSessionsCachedPage) async { do { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); let data = try JSONEncoder().encode(Box(version: version, page: page)); try data.write(to: url, options: [.atomic]) } catch {} }
    func purge() async { try? FileManager.default.removeItem(at: url) }
    private struct Box: Codable { let version: Int; let page: RealSessionsCachedPage }
}
