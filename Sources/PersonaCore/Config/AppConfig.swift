import Foundation

public enum WallpaperMode: String, Codable, Equatable {
    case overlay
    case system
    case none
}

public enum BarLevel: String, Codable, Equatable {
    case mainMenuMinusOne
    case statusBar
}

public enum TilingAlgorithm: String, Codable, Equatable {
    case dwindle
    case masterStack
}

public struct WallpaperConfig: Codable, Equatable {
    public var mode: WallpaperMode

    public init(mode: WallpaperMode = .overlay) {
        self.mode = mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decodeIfPresent(WallpaperMode.self, forKey: .mode) ?? .overlay
    }
}

public struct TopBarConfig: Codable, Equatable {
    public var height: CGFloat
    public var marginTop: CGFloat
    public var marginSide: CGFloat
    public var level: BarLevel

    public init(
        height: CGFloat = 34,
        marginTop: CGFloat = 6,
        marginSide: CGFloat = 10,
        level: BarLevel = .mainMenuMinusOne
    ) {
        self.height = height
        self.marginTop = marginTop
        self.marginSide = marginSide
        self.level = level
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.height = try container.decodeIfPresent(CGFloat.self, forKey: .height) ?? 34
        self.marginTop = try container.decodeIfPresent(CGFloat.self, forKey: .marginTop) ?? 6
        self.marginSide = try container.decodeIfPresent(CGFloat.self, forKey: .marginSide) ?? 10
        self.level = try container.decodeIfPresent(BarLevel.self, forKey: .level) ?? .mainMenuMinusOne
    }
}

public struct HUDConfig: Codable, Equatable {
    public var primaryScreenOnly: Bool
    public var ambientAnimation: Bool
    public var fps: Int

    public init(
        primaryScreenOnly: Bool = true,
        ambientAnimation: Bool = true,
        fps: Int = 30
    ) {
        self.primaryScreenOnly = primaryScreenOnly
        self.ambientAnimation = ambientAnimation
        self.fps = fps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryScreenOnly = try container.decodeIfPresent(Bool.self, forKey: .primaryScreenOnly) ?? true
        self.ambientAnimation = try container.decodeIfPresent(Bool.self, forKey: .ambientAnimation) ?? true
        self.fps = try container.decodeIfPresent(Int.self, forKey: .fps) ?? 30
    }
}

public struct GapsConfig: Codable, Equatable {
    public var outer: CGFloat
    public var inner: CGFloat

    public init(outer: CGFloat = 12, inner: CGFloat = 10) {
        self.outer = outer
        self.inner = inner
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.outer = try container.decodeIfPresent(CGFloat.self, forKey: .outer) ?? 12
        self.inner = try container.decodeIfPresent(CGFloat.self, forKey: .inner) ?? 10
    }
}

public struct TilingConfig: Codable, Equatable {
    public var enabled: Bool
    public var algorithm: TilingAlgorithm
    public var splitRatio: CGFloat
    public var gaps: GapsConfig
    public var snapBackOnDrag: Bool
    public var floatApps: [String]

    public init(
        enabled: Bool = true,
        algorithm: TilingAlgorithm = .dwindle,
        splitRatio: CGFloat = 0.5,
        gaps: GapsConfig = GapsConfig(),
        snapBackOnDrag: Bool = true,
        floatApps: [String] = [
            "com.apple.systempreferences",
            "com.apple.calculator",
            "dev.persona.mode"
        ]
    ) {
        self.enabled = enabled
        self.algorithm = algorithm
        self.splitRatio = splitRatio
        self.gaps = gaps
        self.snapBackOnDrag = snapBackOnDrag
        self.floatApps = floatApps
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.algorithm = try container.decodeIfPresent(TilingAlgorithm.self, forKey: .algorithm) ?? .dwindle
        self.splitRatio = try container.decodeIfPresent(CGFloat.self, forKey: .splitRatio) ?? 0.5
        self.gaps = try container.decodeIfPresent(GapsConfig.self, forKey: .gaps) ?? GapsConfig()
        self.snapBackOnDrag = try container.decodeIfPresent(Bool.self, forKey: .snapBackOnDrag) ?? true
        self.floatApps = try container.decodeIfPresent([String].self, forKey: .floatApps) ?? [
            "com.apple.systempreferences",
            "com.apple.calculator",
            "dev.persona.mode"
        ]
    }
}

public struct BorderConfig: Codable, Equatable {
    public var enabled: Bool
    public var width: CGFloat
    public var cornerRadius: CGFloat
    public var color: String
    public var pulse: Bool

    public init(
        enabled: Bool = true,
        width: CGFloat = 3,
        cornerRadius: CGFloat = 16,
        color: String = "#00d8ff",
        pulse: Bool = true
    ) {
        self.enabled = enabled
        self.width = width
        self.cornerRadius = cornerRadius
        self.color = color
        self.pulse = pulse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 3
        self.cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 16
        self.color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#00d8ff"
        self.pulse = try container.decodeIfPresent(Bool.self, forKey: .pulse) ?? true
    }
}

public struct TerminalConfig: Codable, Equatable {
    public var preference: [String]

    public init(preference: [String] = ["ghostty", "kitty", "wezterm", "alacritty", "terminal"]) {
        self.preference = preference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.preference = try container.decodeIfPresent([String].self, forKey: .preference) ?? [
            "ghostty", "kitty", "wezterm", "alacritty", "terminal"
        ]
    }
}

public struct HotkeysConfig: Codable, Equatable {
    public var launcher: String
    public var tile: String
    public var toggleFloat: String
    public var terminal: String
    public var panic: String
    public var space1: String
    public var space2: String
    public var space3: String
    public var space4: String
    public var space5: String

    public init(
        launcher: String = "opt+space",
        tile: String = "ctrl+opt+t",
        toggleFloat: String = "ctrl+opt+f",
        terminal: String = "ctrl+opt+return",
        panic: String = "ctrl+opt+cmd+q",
        space1: String = "ctrl+opt+1",
        space2: String = "ctrl+opt+2",
        space3: String = "ctrl+opt+3",
        space4: String = "ctrl+opt+4",
        space5: String = "ctrl+opt+5"
    ) {
        self.launcher = launcher
        self.tile = tile
        self.toggleFloat = toggleFloat
        self.terminal = terminal
        self.panic = panic
        self.space1 = space1
        self.space2 = space2
        self.space3 = space3
        self.space4 = space4
        self.space5 = space5
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.launcher = try container.decodeIfPresent(String.self, forKey: .launcher) ?? "opt+space"
        self.tile = try container.decodeIfPresent(String.self, forKey: .tile) ?? "ctrl+opt+t"
        self.toggleFloat = try container.decodeIfPresent(String.self, forKey: .toggleFloat) ?? "ctrl+opt+f"
        self.terminal = try container.decodeIfPresent(String.self, forKey: .terminal) ?? "ctrl+opt+return"
        self.panic = try container.decodeIfPresent(String.self, forKey: .panic) ?? "ctrl+opt+cmd+q"
        self.space1 = try container.decodeIfPresent(String.self, forKey: .space1) ?? "ctrl+opt+1"
        self.space2 = try container.decodeIfPresent(String.self, forKey: .space2) ?? "ctrl+opt+2"
        self.space3 = try container.decodeIfPresent(String.self, forKey: .space3) ?? "ctrl+opt+3"
        self.space4 = try container.decodeIfPresent(String.self, forKey: .space4) ?? "ctrl+opt+4"
        self.space5 = try container.decodeIfPresent(String.self, forKey: .space5) ?? "ctrl+opt+5"
    }
}

public struct GuardianConfig: Codable, Equatable {
    public var enabled: Bool
    public var hangSeconds: Int

    public init(enabled: Bool = true, hangSeconds: Int = 15) {
        self.enabled = enabled
        self.hangSeconds = hangSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.hangSeconds = try container.decodeIfPresent(Int.self, forKey: .hangSeconds) ?? 15
    }
}

public struct AppConfig: Codable, Equatable {
    public var wallpaper: WallpaperConfig
    public var topBar: TopBarConfig
    public var hud: HUDConfig
    public var tiling: TilingConfig
    public var border: BorderConfig
    public var terminal: TerminalConfig
    public var hotkeys: HotkeysConfig
    public var guardian: GuardianConfig

    public init(
        wallpaper: WallpaperConfig = WallpaperConfig(),
        topBar: TopBarConfig = TopBarConfig(),
        hud: HUDConfig = HUDConfig(),
        tiling: TilingConfig = TilingConfig(),
        border: BorderConfig = BorderConfig(),
        terminal: TerminalConfig = TerminalConfig(),
        hotkeys: HotkeysConfig = HotkeysConfig(),
        guardian: GuardianConfig = GuardianConfig()
    ) {
        self.wallpaper = wallpaper
        self.topBar = topBar
        self.hud = hud
        self.tiling = tiling
        self.border = border
        self.terminal = terminal
        self.hotkeys = hotkeys
        self.guardian = guardian
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.wallpaper = try container.decodeIfPresent(WallpaperConfig.self, forKey: .wallpaper) ?? WallpaperConfig()
        self.topBar = try container.decodeIfPresent(TopBarConfig.self, forKey: .topBar) ?? TopBarConfig()
        self.hud = try container.decodeIfPresent(HUDConfig.self, forKey: .hud) ?? HUDConfig()
        self.tiling = try container.decodeIfPresent(TilingConfig.self, forKey: .tiling) ?? TilingConfig()
        self.border = try container.decodeIfPresent(BorderConfig.self, forKey: .border) ?? BorderConfig()
        self.terminal = try container.decodeIfPresent(TerminalConfig.self, forKey: .terminal) ?? TerminalConfig()
        self.hotkeys = try container.decodeIfPresent(HotkeysConfig.self, forKey: .hotkeys) ?? HotkeysConfig()
        self.guardian = try container.decodeIfPresent(GuardianConfig.self, forKey: .guardian) ?? GuardianConfig()
    }

    public mutating func validateAndClamp() -> [String] {
        var warnings: [String] = []

        // Validation clamps:
        // 1. border.width <= gaps.inner
        if border.width > tiling.gaps.inner {
            warnings.append("border.width (\(border.width)) exceeds tiling.gaps.inner (\(tiling.gaps.inner)); clamping border.width")
            border.width = tiling.gaps.inner
        }

        // 2. splitRatio in [0.2, 0.8]
        if tiling.splitRatio < 0.2 {
            warnings.append("tiling.splitRatio (\(tiling.splitRatio)) is below 0.2; clamping to 0.2")
            tiling.splitRatio = 0.2
        } else if tiling.splitRatio > 0.8 {
            warnings.append("tiling.splitRatio (\(tiling.splitRatio)) is above 0.8; clamping to 0.8")
            tiling.splitRatio = 0.8
        }

        // 3. hex color format: ^#[0-9a-fA-F]{6}$
        let hexPattern = "^#[0-9a-fA-F]{6}$"
        if border.color.range(of: hexPattern, options: .regularExpression) == nil {
            warnings.append("border.color '\(border.color)' is not a valid 6-character hex color; falling back to '#00d8ff'")
            border.color = "#00d8ff"
        }

        return warnings
    }

    public static func load(userFile: URL? = nil) -> (AppConfig, [String]) {
        var warnings: [String] = []
        guard let url = userFile, FileManager.default.fileExists(atPath: url.path) else {
            var defaultConfig = AppConfig()
            warnings.append(contentsOf: defaultConfig.validateAndClamp())
            return (defaultConfig, warnings)
        }

        do {
            let data = try Data(contentsOf: url)
            var config = try JSONDecoder().decode(AppConfig.self, from: data)
            warnings.append(contentsOf: config.validateAndClamp())
            return (config, warnings)
        } catch {
            warnings.append("Failed to parse config at \(url.path): \(error.localizedDescription). Falling back to defaults.")
            var defaultConfig = AppConfig()
            warnings.append(contentsOf: defaultConfig.validateAndClamp())
            return (defaultConfig, warnings)
        }
    }
}
