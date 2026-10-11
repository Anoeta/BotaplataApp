import Foundation

/// Reference sRGB palette. No approximate conversion from unavailable OKLCH sources.
enum MidnightPalette: UInt32, CaseIterable, Sendable {
    case background = 0x0D1422
    case surface = 0x172234
    case surfaceElevated = 0x1D2B40
    case border = 0x2A3548
    case textPrimary = 0xF2F5FB
    case textSecondary = 0x9AAAC0
    case accentMint = 0x79D9C1
    case success = 0x69CFA3
    case loss = 0xE87973
    case warning = 0xE8B35C
    case info = 0x79A7EA
}
