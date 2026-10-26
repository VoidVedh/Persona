import Foundation

public struct OriginalValue<T: Codable & Equatable>: Codable, Equatable {
    public var present: Bool
    public var value: T?

    public init(present: Bool, value: T? = nil) {
        self.present = present
        self.value = value
    }
}

public struct DockSnapshot: Codable, Equatable {
    public var autohide: OriginalValue<Bool>

    public init(autohide: OriginalValue<Bool>) {
        self.autohide = autohide
    }
}

public struct MenuBarSnapshot: Codable, Equatable {
    public var hideMenuBar: OriginalValue<Bool>
    public var visibleInFullscreen: OriginalValue<Bool>
    public var scriptedAutohide: Bool?
    public var mechanism: String

    public init(
        hideMenuBar: OriginalValue<Bool>,
        visibleInFullscreen: OriginalValue<Bool>,
        scriptedAutohide: Bool? = nil,
        mechanism: String = "systemEvents"
    ) {
        self.hideMenuBar = hideMenuBar
        self.visibleInFullscreen = visibleInFullscreen
        self.scriptedAutohide = scriptedAutohide
        self.mechanism = mechanism
    }
}

public struct WallpaperOptions: Codable, Equatable {
    public var imageScaling: Int?
    public var allowClipping: Bool?
    public var fillColorHex: String?

    public init(imageScaling: Int? = nil, allowClipping: Bool? = nil, fillColorHex: String? = nil) {
        self.imageScaling = imageScaling
        self.allowClipping = allowClipping
        self.fillColorHex = fillColorHex
    }
}

public struct WallpaperSnapshot: Codable, Equatable {
    public var displayUUID: String
    public var name: String
    public var url: String
    public var options: WallpaperOptions?
    public var isRestorable: Bool

    public init(
        displayUUID: String,
        name: String,
        url: String,
        options: WallpaperOptions? = nil,
        isRestorable: Bool = true
    ) {
        self.displayUUID = displayUUID
        self.name = name
        self.url = url
        self.options = options
        self.isRestorable = isRestorable
    }
}

public struct SystemStateSnapshot: Codable, Equatable {
    public var dock: DockSnapshot
    public var menuBar: MenuBarSnapshot
    public var wallpapers: [WallpaperSnapshot]

    public init(dock: DockSnapshot, menuBar: MenuBarSnapshot, wallpapers: [WallpaperSnapshot]) {
        self.dock = dock
        self.menuBar = menuBar
        self.wallpapers = wallpapers
    }
}
