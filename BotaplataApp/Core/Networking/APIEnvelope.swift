import Foundation

struct APIEnvelope<Payload: Codable & Sendable>: Codable, Sendable {
    let ok: Bool
    let version: String
    let data: Payload?
    let error: APIErrorPayload?
    let meta: APIMeta
    let warnings: [APIWarning]

    init(ok: Bool, version: String = "mobile_v1", data: Payload?, error: APIErrorPayload?, meta: APIMeta, warnings: [APIWarning] = []) {
        self.ok = ok; self.version = version; self.data = data; self.error = error; self.meta = meta; self.warnings = warnings
    }
}
