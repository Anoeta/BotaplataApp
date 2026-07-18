import Foundation

enum JSONCoding {
    static let encoder: JSONEncoder = { JSONEncoder() }()
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = parseISO8601Date(value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
        }
        return decoder
    }()
    private static func parseISO8601Date(_ value: String) -> Date? {
        let iso8601WithFractions = ISO8601DateFormatter()
        iso8601WithFractions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601WithFractions.date(from: value) { return date }

        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime]
        return iso8601.date(from: value)
    }
}
