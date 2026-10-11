import SwiftUI
import UIKit

enum BotaplataColors {
    private static func adaptive(light: UIColor, dark: MidnightPalette) -> Color {
        let hex = dark.rawValue
        let midnight = UIColor(red: CGFloat((hex >> 16) & 0xff) / 255,
                               green: CGFloat((hex >> 8) & 0xff) / 255,
                               blue: CGFloat(hex & 0xff) / 255, alpha: 1)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? midnight : light })
    }
    static let background = adaptive(light: UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1), dark: .background)
    static let surface = adaptive(light: .systemBackground, dark: .surface)
    static let elevated = adaptive(light: .secondarySystemBackground, dark: .surfaceElevated)
    static let border = adaptive(light: .separator, dark: .border)
    static let textPrimary = adaptive(light: .label, dark: .textPrimary)
    static let textSecondary = adaptive(light: .secondaryLabel, dark: .textSecondary)
    static let accent = adaptive(light: UIColor(red: 0.02, green: 0.42, blue: 0.34, alpha: 1), dark: .accentMint)
    static let success = adaptive(light: UIColor(red: 0.07, green: 0.42, blue: 0.20, alpha: 1), dark: .success)
    static let danger = adaptive(light: UIColor(red: 0.65, green: 0.16, blue: 0.14, alpha: 1), dark: .loss)
    static let warning = adaptive(light: UIColor(red: 0.57, green: 0.30, blue: 0.02, alpha: 1), dark: .warning)
    static let info = adaptive(light: .systemBlue, dark: .info)
    // Compatibility aliases keep existing authentication and supervision components coherent.
    static let backgroundDeep = background
    static let backgroundNavy = elevated
    static let backgroundElevated = surface
    static let cardGlass = surface
    static let cardBorder = border
    static let primaryMint = accent
    static let primaryTeal = accent
    static let accentCyan = info
    static let accentMagenta = danger
    static let textMuted = textSecondary
    static let textDisabled = textSecondary
    static let separator = border
    static let graphite = textSecondary
    static let card = surface
    static let neutral = textSecondary
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
    static let metricValue = Font.title.weight(.semibold).monospacedDigit()
    static let body = Font.body
    static let caption = Font.caption.weight(.medium)
    static let eyebrow = Font.caption.weight(.semibold)
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
    static let lg: CGFloat = 16
    static let xl: CGFloat = 16
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

    static func applyNavigationAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(BotaplataColors.backgroundDeep.opacity(0.92))
        appearance.titleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.textPrimary)]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(BotaplataColors.primaryTeal)
    }

    static func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BotaplataColors.surface)
        appearance.shadowColor = UIColor(BotaplataColors.border)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(BotaplataColors.primaryTeal)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.primaryTeal)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(BotaplataColors.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.textSecondary)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
