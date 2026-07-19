import Foundation

nonisolated enum DiagnosticsConfiguration {
    #if DEBUG
    static let verboseNetworkLogs = true
    static let keepsNetworkHistory = true
    #else
    static let verboseNetworkLogs = false
    static let keepsNetworkHistory = false
    #endif
}

nonisolated enum APIEndpointTimeoutPolicy {
    static func timeout(for path: String) -> TimeInterval {
        if path == "/health" || path == "health" { return 4 }
        if path.contains("/auth/login") { return 15 }
        if path.contains("/auth/refresh") { return 9 }
        if path.contains("/active") || path.contains("/dashboard") { return 12 }
        if path.contains("/real/sessions") && path.contains("/chart") { return 18 }
        if path.contains("/real/sessions") { return 12 }
        return 15
    }
}
