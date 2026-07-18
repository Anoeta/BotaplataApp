import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
import Combine

@MainActor final class PushNotificationEventBridge: ObservableObject { var onDeviceToken: ((String) -> Void)?; var onNotificationTap: ((NotificationNavigationTarget?, String?) -> Void)?; var onForeground: (() -> Void)?; func receiveDeviceToken(_ data: Data) { onDeviceToken?(data.map { String(format: "%02x", $0) }.joined()) } }

#if canImport(UserNotifications) && canImport(UIKit)
import UIKit
final class BotaplataAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static weak var bridge: PushNotificationEventBridge?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool { UNUserNotificationCenter.current().delegate = self; return true }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) { Task { @MainActor in Self.bridge?.receiveDeviceToken(deviceToken) } }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) { }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { await MainActor.run { Self.bridge?.onForeground?() }; return [] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async { let parsed = PushPayloadParser.parse(response.notification.request.content.userInfo); await MainActor.run { Self.bridge?.onNotificationTap?(parsed.target, parsed.notificationID) } }
}
#endif

enum PushPayloadParser { static func parse(_ userInfo: [AnyHashable: Any]) -> (target: NotificationNavigationTarget?, notificationID: String?) { let root = (userInfo["botaplata"] as? [String: Any]) ?? userInfo.reduce(into: [String: Any]()) { if let k = $1.key as? String { $0[k] = $1.value } }; let id = root["notification_id"] as? String ?? root["id"] as? String; let nav = root["navigation_target"] as? [String: Any] ?? root; guard let kindRaw = nav["kind"] as? String else { return (nil, id) }; let kind = NotificationNavigationTarget.Kind(rawValue: kindRaw) ?? .unknown; let section = NotificationNavigationTarget.Section(rawValue: nav["section"] as? String ?? "overview") ?? .overview; return (.init(kind: kind, sessionID: nav["session_id"] as? String, section: section), id) } }

