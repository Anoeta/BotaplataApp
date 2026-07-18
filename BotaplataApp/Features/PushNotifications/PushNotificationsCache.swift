import Foundation
nonisolated protocol PushNotificationsCache: Sendable { func load() async -> PushNotificationsCacheSnapshot?; func save(_ snapshot: PushNotificationsCacheSnapshot) async; func purge() async }
nonisolated struct PushNotificationsCacheSnapshot: Codable, Equatable, Sendable { let notifications: [RealNotificationItem]; let summary: RealNotificationSummary?; let preferences: PushPreferences?; let savedAt: Date }
nonisolated struct FilePushNotificationsCache: PushNotificationsCache { private let url: URL; private let version = 1; init(directory: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory) { url = directory.appendingPathComponent("botaplata-real-notifications-cache-v1.json") }
    func load() async -> PushNotificationsCacheSnapshot? { do { let box = try JSONDecoder().decode(Box.self, from: try Data(contentsOf: url)); return box.version == version ? box.snapshot : nil } catch { return nil } }
    func save(_ snapshot: PushNotificationsCacheSnapshot) async { do { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true); try JSONEncoder().encode(Box(version: version, snapshot: snapshot)).write(to: url, options: .atomic) } catch {} }
    func purge() async { try? FileManager.default.removeItem(at: url) }
    private nonisolated struct Box: Codable { let version: Int; let snapshot: PushNotificationsCacheSnapshot }
}
