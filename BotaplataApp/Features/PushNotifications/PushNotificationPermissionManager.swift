import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(UIKit)
import UIKit
#endif

enum PushAuthorizationStatus: String, Codable, Sendable { case notDetermined, denied, authorized, provisional, ephemeral, unknown }
protocol PushNotificationPermissionManaging: Sendable { func authorizationStatus() async -> PushAuthorizationStatus; func requestAuthorizationAndRegister() async throws -> PushAuthorizationStatus }
struct PushNotificationPermissionManager: PushNotificationPermissionManaging {
    func authorizationStatus() async -> PushAuthorizationStatus {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return PushAuthorizationStatus(settings.authorizationStatus)
        #else
        return .unknown
        #endif
    }
    @MainActor func requestAuthorizationAndRegister() async throws -> PushAuthorizationStatus {
        #if canImport(UserNotifications) && canImport(UIKit)
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        let status = await authorizationStatus()
        if granted || status == .authorized || status == .provisional { UIApplication.shared.registerForRemoteNotifications() }
        return status
        #else
        return .unknown
        #endif
    }
}
struct MockPushNotificationPermissionManager: PushNotificationPermissionManaging { var status: PushAuthorizationStatus = .authorized; func authorizationStatus() async -> PushAuthorizationStatus { status }; func requestAuthorizationAndRegister() async throws -> PushAuthorizationStatus { status } }
#if canImport(UserNotifications)
extension PushAuthorizationStatus { init(_ status: UNAuthorizationStatus) { switch status { case .notDetermined: self = .notDetermined; case .denied: self = .denied; case .authorized: self = .authorized; case .provisional: self = .provisional; case .ephemeral: self = .ephemeral; @unknown default: self = .unknown } } }
#endif
