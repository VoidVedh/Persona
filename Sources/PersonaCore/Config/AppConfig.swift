import CoreGraphics
import Foundation

public enum UIEngine: String, Codable, Equatable {
    case web
    case swiftui
}

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

public enum BorderStyle: String, Codable, Equatable {
    case p3r
    case plain
}

public struct UIConfig: Codable, Equatable {
    public var engine: UIEngine
    public var debugInspector: Bool

    public init(engine: UIEngine = .web, debugInspector: Bool = false) {
        self.engine = engine
        self.debugInspector = debugInspector
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.engine = try container.decodeIfPresent(UIEngine.self, forKey: .engine) ?? .web
        self.debugInspector = try container.decodeIfPresent(Bool.self, forKey: .debugInspector) ?? false
    }
}

public struct WallpaperConfig: Codable, Equatable {
    public var mode: WallpaperMode
    public var image: String

    public init(mode: WallpaperMode = .overlay, image: String = "bundled") {
        self.mode = mode
        self.image = image
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mode = try container.decodeIfPresent(WallpaperMode.self, forKey: .mode) ?? .overlay
        self.image = try container.decodeIfPresent(String.self, forKey: .image) ?? "bundled"
    }
}

public struct TopBarConfig: Codable, Equatable {
    public var height: CGFloat
    public var marginTop: CGFloat
    public var marginSide: CGFloat
    public var level: BarLevel

    public init(
        height: CGFloat = 44,
        marginTop: CGFloat = 6,
        marginSide: CGFloat = 10,
        level: BarLevel = .statusBar
    ) {
        self.height = height
        self.marginTop = marginTop
        self.marginSide = marginSide
        self.level = level
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.height = try container.decodeIfPresent(CGFloat.self, forKey: .height) ?? 44
        self.marginTop = try container.decodeIfPresent(CGFloat.self, forKey: .marginTop) ?? 6
        self.marginSide = try container.decodeIfPresent(CGFloat.self, forKey: .marginSide) ?? 10
        self.level = try container.decodeIfPresent(BarLevel.self, forKey: .level) ?? .statusBar
    }
}

public struct HUDConfig: Codable, Equatable {
    public var primaryScreenOnly: Bool
    public var ambientAnimation: Bool
    public var fps: Int
    public var particles: Int
    public var calmOnBattery: Bool

    public init(
        primaryScreenOnly: Bool = true,
        ambientAnimation: Bool = true,
        fps: Int = 24,
        particles: Int = 28,
        calmOnBattery: Bool = true
    ) {
        self.primaryScreenOnly = primaryScreenOnly
        self.ambientAnimation = ambientAnimation
        self.fps = fps
        self.particles = particles
        self.calmOnBattery = calmOnBattery
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryScreenOnly = try container.decodeIfPresent(Bool.self, forKey: .primaryScreenOnly) ?? true
        self.ambientAnimation = try container.decodeIfPresent(Bool.self, forKey: .ambientAnimation) ?? true
        self.fps = try container.decodeIfPresent(Int.self, forKey: .fps) ?? 24
        self.particles = try container.decodeIfPresent(Int.self, forKey: .particles) ?? 28
        self.calmOnBattery = try container.decodeIfPresent(Bool.self, forKey: .calmOnBattery) ?? true
    }
}

public struct LauncherConfig: Codable, Equatable {
    public var width: CGFloat
    public var height: CGFloat

    public init(width: CGFloat = 980, height: CGFloat = 560) {
        self.width = width
        self.height = height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 980
        self.height = try container.decodeIfPresent(CGFloat.self, forKey: .height) ?? 560
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
    public var style: BorderStyle
    public var width: CGFloat
    public var cornerRadius: CGFloat
    public var bracketLength: CGFloat
    public var color: String
    public var pulse: Bool

    public init(
        enabled: Bool = true,
        style: BorderStyle = .p3r,
        width: CGFloat = 3,
        cornerRadius: CGFloat = 16,
        bracketLength: CGFloat = 28,
        color: String = "#00d8ff",
        pulse: Bool = true
    ) {
        self.enabled = enabled
        self.style = style
        self.width = width
        self.cornerRadius = cornerRadius
        self.bracketLength = bracketLength
        self.color = color
        self.pulse = pulse
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.style = try container.decodeIfPresent(BorderStyle.self, forKey: .style) ?? .p3r
        self.width = try container.decodeIfPresent(CGFloat.self, forKey: .width) ?? 3
        self.cornerRadius = try container.decodeIfPresent(CGFloat.self, forKey: .cornerRadius) ?? 16
        self.bracketLength = try container.decodeIfPresent(CGFloat.self, forKey: .bracketLength) ?? 28
        self.color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#00d8ff"
        self.pulse = try container.decodeIfPresent(Bool.self, forKey: .pulse) ?? true
    }
}

public struct SoundConfig: Codable, Equatable {
    public var enabled: Bool
    public var volume: Double

    public init(enabled: Bool = true, volume: Double = 0.35) {
        self.enabled = enabled
        self.volume = volume
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        self.volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 0.35
    }
}

public struct ShowcaseConfig: Codable, Equatable {
    public var closeOnExit: Bool

    public init(closeOnExit: Bool = false) {
        self.closeOnExit = closeOnExit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.closeOnExit = try container.decodeIfPresent(Bool.self, forKey: .closeOnExit) ?? false
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
    public var showcase: String
    public var mute: String
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
        showcase: String = "ctrl+opt+s",
        mute: String = "ctrl+opt+m",
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
        self.showcase = showcase
        self.mute = mute
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
        self.showcase = try container.decodeIfPresent(String.self, forKey: .showcase) ?? "ctrl+opt+s"
        self.mute = try container.decodeIfPresent(String.self, forKey: .mute) ?? "ctrl+opt+m"
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
    public var ui: UIConfig
    public var wallpaper: WallpaperConfig
    public var topBar: TopBarConfig
    public var hud: HUDConfig
    public var launcher: LauncherConfig
    public var tiling: TilingConfig
    public var border: BorderConfig
    public var sound: SoundConfig
    public var showcase: ShowcaseConfig
    public var terminal: TerminalConfig
    public var hotkeys: HotkeysConfig
    public var guardian: GuardianConfig

    public init(
        ui: UIConfig = UIConfig(),
        wallpaper: WallpaperConfig = WallpaperConfig(),
        topBar: TopBarConfig = TopBarConfig(),
        hud: HUDConfig = HUDConfig(),
        launcher: LauncherConfig = LauncherConfig(),
        tiling: TilingConfig = TilingConfig(),
        border: BorderConfig = BorderConfig(),
        sound: SoundConfig = SoundConfig(),
        showcase: ShowcaseConfig = ShowcaseConfig(),
        terminal: TerminalConfig = TerminalConfig(),
        hotkeys: HotkeysConfig = HotkeysConfig(),
        guardian: GuardianConfig = GuardianConfig()
    ) {
        self.ui = ui
        self.wallpaper = wallpaper
        self.topBar = topBar
        self.hud = hud
        self.launcher = launcher
        self.tiling = tiling
        self.border = border
        self.sound = sound
        self.showcase = showcase
        self.terminal = terminal
        self.hotkeys = hotkeys
        self.guardian = guardian
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ui = try container.decodeIfPresent(UIConfig.self, forKey: .ui) ?? UIConfig()
        self.wallpaper = try container.decodeIfPresent(WallpaperConfig.self, forKey: .wallpaper) ?? WallpaperConfig()
        self.topBar = try container.decodeIfPresent(TopBarConfig.self, forKey: .topBar) ?? TopBarConfig()
        self.hud = try container.decodeIfPresent(HUDConfig.self, forKey: .hud) ?? HUDConfig()
        self.launcher = try container.decodeIfPresent(LauncherConfig.self, forKey: .launcher) ?? LauncherConfig()
        self.tiling = try container.decodeIfPresent(TilingConfig.self, forKey: .tiling) ?? TilingConfig()
        self.border = try container.decodeIfPresent(BorderConfig.self, forKey: .border) ?? BorderConfig()
        self.sound = try container.decodeIfPresent(SoundConfig.self, forKey: .sound) ?? SoundConfig()
        self.showcase = try container.decodeIfPresent(ShowcaseConfig.self, forKey: .showcase) ?? ShowcaseConfig()
        self.terminal = try container.decodeIfPresent(TerminalConfig.self, forKey: .terminal) ?? TerminalConfig()
        self.hotkeys = try container.decodeIfPresent(HotkeysConfig.self, forKey: .hotkeys) ?? HotkeysConfig()
        self.guardian = try container.decodeIfPresent(GuardianConfig.self, forKey: .guardian) ?? GuardianConfig()
    }

    public mutating func validateAndClamp() -> [String] {
        var warnings: [String] = []

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

        // 4. hud.fps in [12, 30]
        if hud.fps < 12 {
            warnings.append("hud.fps (\(hud.fps)) is below 12; clamping to 12")
            hud.fps = 12
        } else if hud.fps > 30 {
            warnings.append("hud.fps (\(hud.fps)) exceeds 30; clamping to 30")
            hud.fps = 30
        }

        // 5. hud.particles in [0, 48]
        if hud.particles < 0 {
            warnings.append("hud.particles (\(hud.particles)) is below 0; clamping to 0")
            hud.particles = 0
        } else if hud.particles > 48 {
            warnings.append("hud.particles (\(hud.particles)) exceeds 48; clamping to 48")
            hud.particles = 48
        }

        // 6. border.bracketLength in [16, 48]
        if border.bracketLength < 16 {
            warnings.append("border.bracketLength (\(border.bracketLength)) is below 16; clamping to 16")
            border.bracketLength = 16
        } else if border.bracketLength > 48 {
            warnings.append("border.bracketLength (\(border.bracketLength)) exceeds 48; clamping to 48")
            border.bracketLength = 48
        }

        // 7. sound.volume in [0.0, 1.0]
        if sound.volume < 0.0 {
            warnings.append("sound.volume (\(sound.volume)) is below 0.0; clamping to 0.0")
            sound.volume = 0.0
        } else if sound.volume > 1.0 {
            warnings.append("sound.volume (\(sound.volume)) exceeds 1.0; clamping to 1.0")
            sound.volume = 1.0
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
