import Foundation

enum SecureLogging {
    private static let sensitiveKeys = ["Authorization", "access_token", "refresh_token", "password", "totp", "code", "secret", "installation_id"]
    static func sanitized(_ value: String) -> String {
        var output = value
        for key in sensitiveKeys {
            let pattern = #"(?i)("?"# + NSRegularExpression.escapedPattern(for: key) + #""?\s*[:=]\s*"?)[^"\s,}]+"#
            output = output.replacingOccurrences(of: pattern, with: "$1<redacted>", options: .regularExpression)
        }
        output = output.replacingOccurrences(of: #"(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]+"#, with: "$1<redacted>", options: .regularExpression)
        return output
    }
}
