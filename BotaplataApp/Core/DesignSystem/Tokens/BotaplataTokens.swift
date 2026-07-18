import SwiftUI
import UIKit

enum BotaplataColors {
    // Lovable-inspired Premium V2 palette for native SwiftUI dark mode.
    static let backgroundDeep = Color(red: 0.01, green: 0.03, blue: 0.07)
    static let backgroundNavy = Color(red: 0.00, green: 0.22, blue: 0.51)
    static let backgroundElevated = Color(red: 0.06, green: 0.11, blue: 0.19)
    static let cardGlass = Color.white.opacity(0.075)
    static let cardBorder = Color.white.opacity(0.14)
    static let primaryMint = Color(red: 0.37, green: 0.80, blue: 0.54)
    static let primaryTeal = Color(red: 0.00, green: 0.60, blue: 0.55)
    static let accentCyan = Color(red: 0.07, green: 0.63, blue: 0.83)
    static let accentMagenta = Color(red: 0.65, green: 0.15, blue: 0.44)
    static let success = primaryMint
    static let warning = Color(red: 0.98, green: 0.71, blue: 0.00)
    static let danger = Color(red: 0.96, green: 0.14, blue: 0.35)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.74)
    static let textMuted = Color.white.opacity(0.52)
    static let separator = Color.white.opacity(0.10)
    static let graphite = Color(red: 0.25, green: 0.25, blue: 0.25)

    // Backward-compatible aliases used by existing screens.
    static let background = backgroundDeep
    static let surface = Color(red: 0.04, green: 0.08, blue: 0.15)
    static let card = backgroundElevated
    static let elevated = Color(red: 0.09, green: 0.15, blue: 0.25)
    static let accent = primaryTeal
    static let neutral = Color.gray
}

enum BotaplataGradients {
    static let appBackground = LinearGradient(
        colors: [BotaplataColors.backgroundDeep, Color(red: 0.01, green: 0.08, blue: 0.17), BotaplataColors.backgroundDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardHero = LinearGradient(colors: [BotaplataColors.backgroundNavy.opacity(0.72), BotaplataColors.primaryTeal.opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardTeal = LinearGradient(colors: [BotaplataColors.primaryTeal.opacity(0.34), BotaplataColors.accentCyan.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardDanger = LinearGradient(colors: [BotaplataColors.danger.opacity(0.30), BotaplataColors.accentMagenta.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let cardWarning = LinearGradient(colors: [BotaplataColors.warning.opacity(0.30), Color(red: 0.97, green: 0.38, blue: 0.00).opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let buttonPrimary = LinearGradient(colors: [BotaplataColors.primaryMint, BotaplataColors.primaryTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let tabBar = LinearGradient(colors: [BotaplataColors.backgroundElevated.opacity(0.96), BotaplataColors.backgroundNavy.opacity(0.40)], startPoint: .top, endPoint: .bottom)
}

enum BotaplataTypography {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let screenTitle = Font.title.weight(.bold)
    static let sectionTitle = Font.title3.weight(.semibold)
    static let cardTitle = Font.headline.weight(.semibold)
    static let metricValue = Font.title2.weight(.bold).monospacedDigit()
    static let body = Font.body
    static let caption = Font.caption.weight(.medium)
    static let monoValue = Font.body.monospacedDigit().weight(.semibold)
}

enum BotaplataSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 44
}

enum BotaplataRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 30
    static let pill: CGFloat = 999
}

enum BotaplataShadow {
    static let cardColor = Color.black.opacity(0.28)
    static let glowTeal = BotaplataColors.primaryTeal.opacity(0.20)
    static let dangerGlow = BotaplataColors.danger.opacity(0.18)
    static let y: CGFloat = 12
    static let radius: CGFloat = 22
}

enum BotaplataBorder { static let subtle: CGFloat = 1 }
enum BotaplataTouch { static let minimum: CGFloat = 44 }
enum BotaplataMotion { static let quick = 0.18; static let standard = 0.28 }

enum BotaplataSymbol {
    static let dashboard = "chart.line.uptrend.xyaxis"
    static let sessions = "rectangle.stack.fill"
    static let journal = "book.pages.fill"
    static let profile = "person.crop.circle.fill"
    static let alerts = "bell.badge.fill"
    static let success = "checkmark.seal.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let critical = "xmark.octagon.fill"
    static let kraken = "network"
    static let security = "lock.shield.fill"
    static let biometry = "faceid"
    static let offline = "wifi.slash"
}

enum BotaplataTheme {
    static func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(BotaplataColors.backgroundElevated.opacity(0.92))
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(BotaplataColors.primaryTeal)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.primaryTeal)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(0.56)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(0.56)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
