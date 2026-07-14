import Foundation

protocol ActiveSessionCache: Sendable { func load() async -> RealActiveSnapshot?; func save(_ snapshot: RealActiveSnapshot) async; func purge() async }

struct FileActiveSessionCache: ActiveSessionCache {
    private let url: URL
    private let version = 1
    init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory) { self.url = directory.appendingPathComponent("botaplata-real-active-snapshot-cache-v1.json") }
    func load() async -> RealActiveSnapshot? {
        do { let data = try Data(contentsOf: url); let box = try JSONDecoder().decode(CacheBox.self, from: data); return box.version == version ? box.snapshot : nil } catch { return nil }
    }
    func save(_ snapshot: RealActiveSnapshot) async { do { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); let data = try JSONEncoder().encode(CacheBox(version: version, snapshot: snapshot)); try data.write(to: url, options: [.atomic]) } catch {} }
    func purge() async { try? FileManager.default.removeItem(at: url) }
    private struct CacheBox: Codable { let version: Int; let snapshot: RealActiveSnapshot }
}
