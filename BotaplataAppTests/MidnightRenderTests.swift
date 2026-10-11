#if DEBUG && canImport(UIKit)
import SwiftUI
import UIKit
import XCTest
@testable import BotaplataApp

/// Run on an iOS simulator. Attachments are review artifacts, not approved golden baselines.
@MainActor final class MidnightRenderTests: XCTestCase {
    func testKeyScreensAtSmallAndLargeWidths() async throws {
        for width: CGFloat in [320, 430] {
            for scenario in MidnightPreviewScenario.allCases {
                try await attach(MidnightPreviewScreen(scenario: scenario), name: "\(scenario.rawValue)-\(Int(width))-dark", width: width, height: 932, scheme: .dark)
            }
        }
    }

    func testAccessibilityAndLightModeScreens() async throws {
        for scenario in [MidnightPreviewScenario.home, .sessions, .analysis, .orders, .journal, .profile] {
            try await attach(MidnightPreviewScreen(scenario: scenario).dynamicTypeSize(.accessibility3), name: "\(scenario.rawValue)-accessibility3", width: 320, height: 932, scheme: .dark)
            try await attach(MidnightPreviewScreen(scenario: scenario), name: "\(scenario.rawValue)-light", width: 393, height: 852, scheme: .light)
        }
    }

    func testFinancialCardAndControlsFitProposedWidthAtLargeText() async throws {
        let view = VStack(alignment: .leading, spacing: 16) {
            PremiumMetricCard(title: "P&L net réalisé", value: "-123 456,1234 USDC", footnote: "Fixture avec valeur longue", tone: .negative)
            PremiumSegmentedControl(title: "Sessions", options: ["Toutes", "En cours", "Terminées"], selection: .constant("En cours"), label: { $0 })
            PremiumPerformanceUnavailableCard()
        }.padding(16).dynamicTypeSize(.accessibility3)
        let controller = UIHostingController(rootView: view)
        let proposed = CGSize(width: 320, height: .greatestFiniteMagnitude)
        let size = controller.sizeThatFits(in: proposed)
        XCTAssertLessThanOrEqual(size.width, 320.5, "Content must accept the narrow screen proposal")
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertTrue(size.height.isFinite)
        try await attach(view, name: "financial-components-accessibility3", width: 320, height: max(1, size.height), scheme: .dark)
    }

    private func attach<Content: View>(_ content: Content, name: String, width: CGFloat, height: CGFloat, scheme: ColorScheme) async throws {
        let root = content.environment(\.colorScheme, scheme)
            .environment(\.locale, Locale(identifier: "fr_FR"))
            .environment(\.accessibilityReduceMotion, true)
            .frame(width: width, height: height).background(BotaplataColors.background)
        let controller = UIHostingController(rootView: root)
        let previousWindow = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
        let window: UIWindow
        if let scene = previousWindow?.windowScene { window = UIWindow(windowScene: scene) }
        else { window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height)) }
        window.frame = CGRect(x: 0, y: 0, width: width, height: height)
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        // Let SwiftUI commit its native hierarchy; all repositories in these views are mocks.
        try await Task.sleep(for: .milliseconds(60))
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        var drawn = false
        let image = renderer.image { _ in drawn = controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true) }
        XCTAssertTrue(drawn, "No native rendering for \(name)")
        XCTAssertEqual(image.size.width, width, accuracy: 0.5)
        XCTAssertEqual(image.size.height, height, accuracy: 0.5)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Midnight-V3-\(name)-FIXTURE"
        attachment.lifetime = .keepAlways
        add(attachment)

    }
}
#endif
