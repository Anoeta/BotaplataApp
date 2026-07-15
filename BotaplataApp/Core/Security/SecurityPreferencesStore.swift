import Foundation

protocol SecurityPreferencesStore: Sendable {
    func biometricLockEnabled() async -> Bool
    func setBiometricLockEnabled(_ enabled: Bool) async
}

actor UserDefaultsSecurityPreferencesStore: SecurityPreferencesStore {
    private let defaults: UserDefaults
    private let key = "botaplata.security.biometricLockEnabled"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func biometricLockEnabled() async -> Bool { defaults.bool(forKey: key) }
    func setBiometricLockEnabled(_ enabled: Bool) async { defaults.set(enabled, forKey: key) }
}
