import Foundation

struct APIWarning: Codable, Equatable, Sendable {
    let code: String
    let message: String
}
