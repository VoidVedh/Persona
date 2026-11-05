import Foundation

/// Single source of truth for the Persona 3 Reload palette and geometry tokens.
/// Hex strings only (Foundation-only); SwiftUI/AppKit mappings live in PersonaKit.
public enum ThemeTokens {
    // MARK: Palette
    /// Electric cyan — primary accent.
    public static let cyan = "#00d8ff"
    /// Royal blue — secondary accent.
    public static let royalBlue = "#0051ff"
    /// Deep midnight — panel fill.
    public static let midnight = "#0a192f"
    /// Near-black background behind the wallpaper gradient.
    public static let abyss = "#050c1a"
    /// Crisp white typography.
    public static let white = "#ffffff"
    /// Ice white — soft text/highlights.
    public static let ice = "#e8f6ff"
    /// Lighter blue used for glows and strokes.
    public static let azure = "#1f6bff"
    /// Muted steel blue for inactive strokes.
    public static let steel = "#3a5a7a"
    public static let warn = "#ffd24a"
    public static let alert = "#ff3b5c"
    /// Teal-green tint of the Dark Hour.
    public static let darkHour = "#5dffcf"

    // MARK: Geometry
    /// Default parallelogram lean in degrees (negative = leans right, "/").
    public static let skewDegrees: Double = -12
    /// Strongest lean allowed anywhere in the UI.
    public static let skewMaxDegrees: Double = -18
    public static let barCornerClip: Double = 10
    public static let pillHeight: Double = 22
    public static let hairlineWidth: Double = 1

    // MARK: Hex / colour math
    public struct RGB: Equatable {
        public let r: Double
        public let g: Double
        public let b: Double
        public init(r: Double, g: Double, b: Double) {
            self.r = r
            self.g = g
            self.b = b
        }
    }

    /// Parses `#rrggbb` (case-insensitive). Returns nil for anything else.
    public static func rgb(hex: String) -> RGB? {
        guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { return nil }
        let digits = hex.dropFirst()
        guard let value = UInt32(digits, radix: 16) else { return nil }
        return RGB(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    /// WCAG relative luminance.
    public static func relativeLuminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// WCAG contrast ratio between two `#rrggbb` colours (1…21); nil when either is invalid.
    public static func contrastRatio(_ hexA: String, _ hexB: String) -> Double? {
        guard let a = rgb(hex: hexA), let b = rgb(hex: hexB) else { return nil }
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Every palette entry, for validation (fastfetch/terminal profiles are cross-checked against it).
    public static let palette: [String: String] = [
        "cyan": cyan, "royalBlue": royalBlue, "midnight": midnight, "abyss": abyss, "white": white,
        "ice": ice, "azure": azure, "steel": steel, "warn": warn, "alert": alert, "darkHour": darkHour,
    ]

    /// Extended terminal ANSI + Bright ANSI palette allowed in terminal profile configs.
    public static let terminalAllowedHexSet: Set<String> = Set(
        palette.values.map { $0.lowercased() } + [
            "#b48cff", // ANSI 5 magenta
            "#ff6b85", // Bright 1 red
            "#8cffdf", // Bright 2 green
            "#ffe07d", // Bright 3 yellow
            "#4d8bff", // Bright 4 blue
            "#ccaeff", // Bright 5 magenta
            "#5ce5ff", // Bright 6 cyan
        ]
    )
}

/// Severity colouring for telemetry pills (§8.1 thresholds).
public enum PillSeverity: String, Equatable {
    case normal
    case warn
    case alert

    /// CPU / RAM: ≥ 85 % is a warning.
    public static func forUsage(_ percent: Double) -> PillSeverity {
        percent >= 85 ? .warn : .normal
    }

    /// Battery: ≤ 20 % and not charging is an alert (the pill also pulses).
    public static func forBattery(percent: Double, charging: Bool) -> PillSeverity {
        (percent <= 20 && !charging) ? .alert : .normal
    }
}
