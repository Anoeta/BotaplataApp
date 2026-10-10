import XCTest
@testable import BotaplataApp

final class ActiveSessionCacheTests: XCTestCase {
    func testSaveLoadOverwritePurgeAndNoSecretSentinels() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = FileActiveSessionCache(directory: directory)
        let awaitedValue3 = await cache.load(); XCTAssertNil(awaitedValue3)
        let first = snapshot(id: "first", generatedAt: ISO8601DateFormatter().date(from: "2026-07-14T14:01:00Z"))
        await cache.save(first)
        let awaitedValue1 = await cache.load(); XCTAssertEqual(awaitedValue1, first)
        let second = snapshot(id: "second", generatedAt: ISO8601DateFormatter().date(from: "2026-07-14T14:02:00Z"))
        await cache.save(second)
        let awaitedValue2 = await cache.load(); XCTAssertEqual(awaitedValue2, second)
        let raw = try String(contentsOf: directory.appendingPathComponent("botaplata-real-active-snapshot-cache-v1.json"), encoding: .utf8)
        for sentinel in ["ACCESS_TOKEN_SENTINEL", "REFRESH_TOKEN_SENTINEL", "KRAKEN_KEY_SENTINEL", "KRAKEN_SECRET_SENTINEL", "PASSWORD_SENTINEL", "TOTP_SENTINEL"] { XCTAssertFalse(raw.contains(sentinel)) }
        await cache.purge()
        let awaitedValue4 = await cache.load(); XCTAssertNil(awaitedValue4)
    }

    func testCorruptedAndIncompatibleCacheReturnNilWithoutCrash() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("botaplata-real-active-snapshot-cache-v1.json")
        let cache = FileActiveSessionCache(directory: directory)
        try Data("not-json".utf8).write(to: url)
        let awaitedValue5 = await cache.load(); XCTAssertNil(awaitedValue5)
        let incompatible = #"{"version":999,"snapshot":{"generatedAt":null,"activeSessionCount":0,"activeSession":null,"warnings":[],"requestID":null,"serverTime":null}}"#
        try Data(incompatible.utf8).write(to: url)
        let awaitedValue6 = await cache.load(); XCTAssertNil(awaitedValue6)
    }

    private func snapshot(id: String, generatedAt: Date?) -> RealActiveSnapshot { RealActiveSnapshot(generatedAt: generatedAt, activeSessionCount: 0, activeSession: nil, warnings: [Warning(id: id, severity: .information, title: "safe", message: "safe")], requestID: id, serverTime: generatedAt) }
}
