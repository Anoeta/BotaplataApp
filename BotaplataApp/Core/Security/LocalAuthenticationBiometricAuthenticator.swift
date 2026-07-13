import Foundation
import LocalAuthentication

struct LocalAuthenticationBiometricAuthenticator: BiometricAuthenticating {
    func availability() async -> BiometricAvailability {
        let context = LAContext(); var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) ? .available : .unavailable
    }
    func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext(); var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return .unavailable }
        do { return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) ? .succeeded : .denied }
        catch { return (error as NSError).code == LAError.userCancel.rawValue ? .cancelled : .denied }
    }
}
