import Foundation

protocol SecurityPreferencesStore: Sendable {
    func biometricLockEnabled() async -> Bool
    func setBiometricLockEnabled(_ enabled: Bool) async
}

actor UserDefaultsSecurityPreferencesStore: SecurityPreferencesStore {
    private let defaults: UserDefaults
    private nonisolated static let key = "botaplata.security.biometricLockEnabled"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func biometricLockEnabled() async -> Bool { defaults.bool(forKey: Self.key) }
    func setBiometricLockEnabled(_ enabled: Bool) async { defaults.set(enabled, forKey: Self.key) }
}
