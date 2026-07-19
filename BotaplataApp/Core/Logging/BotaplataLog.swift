import Foundation
import OSLog

nonisolated enum BotaplataLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "BotaplataApp"
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let auth = Logger(subsystem: subsystem, category: "Auth")
    static let dashboard = Logger(subsystem: subsystem, category: "Dashboard")
    static let sessions = Logger(subsystem: subsystem, category: "Sessions")
    static let lifecycle = Logger(subsystem: subsystem, category: "Lifecycle")
    static let performance = Logger(subsystem: subsystem, category: "Performance")
    static let chart = Logger(subsystem: subsystem, category: "Chart")
    static let pointsOfInterest = OSLog(subsystem: subsystem, category: .pointsOfInterest)
}

nonisolated enum BotaplataSignpost {
    static func begin(_ name: StaticString, id: OSSignpostID = .exclusive) -> OSSignpostID {
        let signpostID = id == .exclusive ? OSSignpostID(log: BotaplataLog.pointsOfInterest) : id
        os_signpost(.begin, log: BotaplataLog.pointsOfInterest, name: name, signpostID: signpostID)
        return signpostID
    }

    static func end(_ name: StaticString, id: OSSignpostID) {
        os_signpost(.end, log: BotaplataLog.pointsOfInterest, name: name, signpostID: id)
    }
}
