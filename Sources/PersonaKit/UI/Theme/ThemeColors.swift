import AppKit
import PersonaCore
import SwiftUI

public extension Color {
    /// `#rrggbb` → Color (falls back to magenta so a bad token is obvious, never invisible).
    init(hex: String, opacity: Double = 1) {
        if let c = ThemeTokens.rgb(hex: hex) {
            self = Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: opacity)
        } else {
            self = Color(.sRGB, red: 1, green: 0, blue: 1, opacity: opacity)
        }
    }
}

public extension NSColor {
    convenience init(hex: String, alpha: CGFloat = 1) {
        if let c = ThemeTokens.rgb(hex: hex) {
            self.init(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha)
        } else {
            self.init(srgbRed: 1, green: 0, blue: 1, alpha: alpha)
        }
    }
}

/// SwiftUI colour tokens mapped 1:1 from `ThemeTokens`.
public enum ThemeColors {
    public static let cyan = Color(hex: ThemeTokens.cyan)
    public static let royalBlue = Color(hex: ThemeTokens.royalBlue)
    public static let midnight = Color(hex: ThemeTokens.midnight)
    public static let abyss = Color(hex: ThemeTokens.abyss)
    public static let white = Color(hex: ThemeTokens.white)
    public static let ice = Color(hex: ThemeTokens.ice)
    public static let azure = Color(hex: ThemeTokens.azure)
    public static let steel = Color(hex: ThemeTokens.steel)
    public static let warn = Color(hex: ThemeTokens.warn)
    public static let alert = Color(hex: ThemeTokens.alert)
    public static let darkHour = Color(hex: ThemeTokens.darkHour)

    public static func tint(for severity: PillSeverity) -> Color {
        switch severity {
        case .normal: return cyan
        case .warn: return warn
        case .alert: return alert
        }
    }
}
