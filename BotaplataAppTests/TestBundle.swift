import Foundation

#if !SWIFT_PACKAGE
private final class BotaplataTestBundleMarker: NSObject {}
extension Bundle {
    /// Match SwiftPM's resource-bundle API when these tests run under Xcode.
    static var module: Bundle { Bundle(for: BotaplataTestBundleMarker.self) }
}
#endif
