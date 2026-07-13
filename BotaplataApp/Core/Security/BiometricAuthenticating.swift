import Foundation

enum BiometricAvailability: Equatable, Sendable { case available, unavailable }
enum BiometricResult: Equatable, Sendable { case succeeded, denied, cancelled, unavailable }

protocol BiometricAuthenticating: Sendable {
    func availability() async -> BiometricAvailability
    func authenticate(reason: String) async -> BiometricResult
}
