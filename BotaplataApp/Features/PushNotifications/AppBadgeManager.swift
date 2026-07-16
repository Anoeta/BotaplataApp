import Foundation
#if canImport(UIKit)
import UIKit
import UserNotifications
#endif

protocol AppBadgeManaging: Sendable { func setBadgeCount(_ count: Int) async }
struct AppBadgeManager: AppBadgeManaging {
    @MainActor func setBadgeCount(_ count: Int) async {
        #if canImport(UIKit)
        if #available(iOS 16.0, *) { try? await UNUserNotificationCenter.current().setBadgeCount(count) } else { UIApplication.shared.applicationIconBadgeNumber = count }
        #endif
    }
}
struct MockAppBadgeManager: AppBadgeManaging { func setBadgeCount(_ count: Int) async {} }
