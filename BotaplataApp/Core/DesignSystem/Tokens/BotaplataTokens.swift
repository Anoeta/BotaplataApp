import SwiftUI
import UIKit

enum BotaplataColors {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    static let backgroundDeep = adaptive(light: UIColor(red: 0.95, green: 0.97, blue: 0.99, alpha: 1), dark: UIColor(red: 0.025, green: 0.045, blue: 0.08, alpha: 1))
    static let backgroundNavy = adaptive(light: .secondarySystemBackground, dark: UIColor(red: 0.04, green: 0.08, blue: 0.15, alpha: 1))
    static let backgroundElevated = adaptive(light: .systemBackground, dark: UIColor(red: 0.055, green: 0.085, blue: 0.13, alpha: 1))
    static let cardGlass = backgroundElevated
    static let cardBorder = Color(uiColor: .separator).opacity(0.45)
    static let primaryMint = adaptive(light: UIColor(red: 0.02, green: 0.42, blue: 0.34, alpha: 1), dark: UIColor(red: 0.35, green: 0.85, blue: 0.69, alpha: 1))
    static let primaryTeal = primaryMint
    static let accentCyan = adaptive(light: .systemBlue, dark: .systemCyan)
    static let accentMagenta = Color(uiColor: .systemPink)
    static let success = adaptive(light: UIColor(red: 0.07, green: 0.42, blue: 0.20, alpha: 1), dark: .systemGreen)
    static let warning = adaptive(light: UIColor(red: 0.62, green: 0.32, blue: 0.02, alpha: 1), dark: .systemYellow)
    static let danger = Color(uiColor: .systemRed)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textMuted = Color(uiColor: .secondaryLabel)
    static let textDisabled = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator)
    static let graphite = Color(uiColor: .systemGray)
    static let background = backgroundDeep
    static let surface = backgroundElevated
    static let card = backgroundElevated
    static let elevated = backgroundNavy
    static let accent = primaryTeal
    static let neutral = Color(uiColor: .secondaryLabel)

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
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(BotaplataColors.backgroundElevated.opacity(0.92))
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(BotaplataColors.primaryTeal)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.primaryTeal)]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(BotaplataColors.textSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(BotaplataColors.textSecondary)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
