import Foundation

public struct WebNotchGeometry: Codable, Equatable {
    public var x: Double
    public var w: Double

    public init(x: Double = 0, w: Double = 0) {
        self.x = x
        self.w = w
    }
}

public struct WebScreenGeometry: Codable, Equatable {
    public var width: Double
    public var height: Double
    public var notch: WebNotchGeometry

    public init(width: Double = 1512, height: Double = 982, notch: WebNotchGeometry = WebNotchGeometry()) {
        self.width = width
        self.height = height
        self.notch = notch
    }
}

public struct WebSpaceItem: Codable, Equatable {
    public var index: Int
    public var active: Bool
    public var occupied: Bool

    public init(index: Int, active: Bool, occupied: Bool = true) {
        self.index = index
        self.active = active
        self.occupied = occupied
    }
}

public struct WebTelemetryState: Codable, Equatable {
    public var cpu: Int
    public var mem: Int
    public var battery: Int?
    public var charging: Bool
    public var wifiBars: Int
    public var volume: Int
    public var muted: Bool

    public init(
        cpu: Int = 18,
        mem: Int = 46,
        battery: Int? = 84,
        charging: Bool = true,
        wifiBars: Int = 4,
        volume: Int = 65,
        muted: Bool = false
    ) {
        self.cpu = cpu
        self.mem = mem
        self.battery = battery
        self.charging = charging
        self.wifiBars = wifiBars
        self.volume = volume
        self.muted = muted
    }
}

public struct WebNowPlayingState: Codable, Equatable {
    public var state: String // "playing" | "paused" | "none"
    public var title: String
    public var artist: String
    public var source: String

    public init(
        state: String = "playing",
        title: String = "COLOR YOUR NIGHT",
        artist: String = "AZUMI TAKAHASHI · LOTUS JUICE",
        source: String = "Music"
    ) {
        self.state = state
        self.title = title
        self.artist = artist
        self.source = source
    }
}

public struct WebMoonState: Codable, Equatable {
    public var p: Double
    public var illum: Double
    public var name: String
    public var toFullDays: Double
    public var countdown: String
    public var under24h: Bool

    public init(
        p: Double = 0.32,
        illum: Double = 0.71,
        name: String = "Waxing Gibbous",
        toFullDays: Double = 5.58,
        countdown: String = "T-05D 14H",
        under24h: Bool = false
    ) {
        self.p = p
        self.illum = illum
        self.name = name
        self.toFullDays = toFullDays
        self.countdown = countdown
        self.under24h = under24h
    }

    public static func from(_ moon: MoonPhase) -> WebMoonState {
        WebMoonState(
            p: (moon.phase * 10000).rounded() / 10000,
            illum: (moon.illumination * 10000).rounded() / 10000,
            name: moon.name.rawValue,
            toFullDays: (moon.toFullDays * 100).rounded() / 100,
            countdown: moon.countdownText,
            under24h: moon.toFullDays < 1.0
        )
    }
}

public struct BarState: Codable, Equatable {
    public var screen: WebScreenGeometry
    public var spaces: [WebSpaceItem]
    public var focusedApp: String
    public var focusedTitle: String
    public var slot: String
    public var phase: String
    public var telemetry: WebTelemetryState
    public var nowPlaying: WebNowPlayingState
    public var clockTime: String
    public var clockDay: String
    public var runMode: String
    public var calm: Bool

    public init(
        screen: WebScreenGeometry = WebScreenGeometry(width: 1512, height: 44),
        spaces: [WebSpaceItem] = [
            WebSpaceItem(index: 1, active: true, occupied: true),
            WebSpaceItem(index: 2, active: false, occupied: true),
            WebSpaceItem(index: 3, active: false, occupied: true),
            WebSpaceItem(index: 4, active: false, occupied: false),
            WebSpaceItem(index: 5, active: false, occupied: false),
        ],
        focusedApp: String = "TERMINAL",
        focusedTitle: String = "zsh — fastfetch · p3r-rice",
        slot: String = "AFTER SCHOOL",
        phase: String = "daytime",
        telemetry: WebTelemetryState = WebTelemetryState(),
        nowPlaying: WebNowPlayingState = WebNowPlayingState(),
        clockTime: String = "16:30",
        clockDay: String = "THU 05",
        runMode: String = "live",
        calm: Bool = false
    ) {
        self.screen = screen
        self.spaces = spaces
        self.focusedApp = focusedApp
        self.focusedTitle = focusedTitle
        self.slot = slot
        self.phase = phase
        self.telemetry = telemetry
        self.nowPlaying = nowPlaying
        self.clockTime = clockTime
        self.clockDay = clockDay
        self.runMode = runMode
        self.calm = calm
    }
}

public struct HudState: Codable, Equatable {
    public var screen: WebScreenGeometry
    public var month: String
    public var day: String
    public var dow: String
    public var slot: String
    public var slotAccent: String
    public var phase: String
    public var moon: WebMoonState
    public var nowPlaying: WebNowPlayingState
    public var wallpaperMode: String
    public var calm: Bool
    public var fps: Int
    public var particles: Int

    public init(
        screen: WebScreenGeometry = WebScreenGeometry(width: 1512, height: 982),
        month: String = "11",
        day: String = "05",
        dow: String = "THU",
        slot: String = "AFTER SCHOOL",
        slotAccent: String = "--cyan",
        phase: String = "daytime",
        moon: WebMoonState = WebMoonState(),
        nowPlaying: WebNowPlayingState = WebNowPlayingState(),
        wallpaperMode: String = "overlay",
        calm: Bool = false,
        fps: Int = 24,
        particles: Int = 28
    ) {
        self.screen = screen
        self.month = month
        self.day = day
        self.dow = dow
        self.slot = slot
        self.slotAccent = slotAccent
        self.phase = phase
        self.moon = moon
        self.nowPlaying = nowPlaying
        self.wallpaperMode = wallpaperMode
        self.calm = calm
        self.fps = fps
        self.particles = particles
    }
}

public struct WebLauncherItemState: Codable, Equatable {
    public var id: String
    public var name: String
    public var subtitle: String
    public var kind: String // "APP" | "CMD" | "EXIT"
    public var iconId: String?
    public var shortcut: String
    public var destructive: Bool
    public var matchIndices: [Int]

    public init(
        id: String,
        name: String,
        subtitle: String,
        kind: String,
        iconId: String? = nil,
        shortcut: String = "",
        destructive: Bool = false,
        matchIndices: [Int] = []
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.kind = kind
        self.iconId = iconId
        self.shortcut = shortcut
        self.destructive = destructive
        self.matchIndices = matchIndices
    }
}

public struct LauncherState: Codable, Equatable {
    public var query: String
    public var selectedIndex: Int
    public var totalCount: Int
    public var phase: String
    public var calm: Bool
    public var items: [WebLauncherItemState]

    public init(
        query: String = "",
        selectedIndex: Int = 0,
        totalCount: Int = 8,
        phase: String = "daytime",
        calm: Bool = false,
        items: [WebLauncherItemState] = [
            WebLauncherItemState(id: "cmd.showcase", name: "LAUNCH P3R SHOWCASE WORKSPACE", subtitle: "Spawn dual-terminal fastfetch + audio/system visualizer", kind: "CMD", shortcut: "⌘1"),
            WebLauncherItemState(id: "cmd.terminal", name: "OPEN TERMINAL (P3R)", subtitle: "Launch isolated Persona 3 Reload terminal session", kind: "CMD", shortcut: "⌘2"),
            WebLauncherItemState(id: "cmd.tile", name: "TILE WINDOWS", subtitle: "Retile all windows on active display", kind: "CMD", shortcut: "⌘3"),
            WebLauncherItemState(id: "cmd.darkhour", name: "TOGGLE DARK HOUR", subtitle: "Switch between Daytime Cyan and Dark Hour Emerald", kind: "CMD", shortcut: "⌘4"),
            WebLauncherItemState(id: "app.safari", name: "SAFARI", subtitle: "/Applications/Safari.app", kind: "APP", iconId: "safari", shortcut: "⌘5"),
            WebLauncherItemState(id: "app.terminal", name: "TERMINAL", subtitle: "/System/Applications/Utilities/Terminal.app", kind: "APP", iconId: "terminal", shortcut: "⌘6"),
            WebLauncherItemState(id: "cmd.float", name: "TOGGLE FLOAT", subtitle: "Float or unfloat the focused window", kind: "CMD", shortcut: "⌘7"),
            WebLauncherItemState(id: "cmd.exit", name: "EXIT PERSONA MODE", subtitle: "Restore macOS Dock, Menu Bar, and window frames", kind: "EXIT", shortcut: "⌘8", destructive: true),
        ]
    ) {
        self.query = query
        self.selectedIndex = selectedIndex
        self.totalCount = totalCount
        self.phase = phase
        self.calm = calm
        self.items = items
    }
}

public enum WebStateJSON {
    public static func encode<T: Encodable>(_ value: T, pretty: Bool = true) throws -> String {
        let encoder = JSONEncoder()
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        } else {
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        }
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    public static func encodeDictionary<T: Encodable>(_ value: T) -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    public static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

