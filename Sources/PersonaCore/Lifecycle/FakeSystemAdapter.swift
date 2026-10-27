import Foundation

public struct FakeWorld: Equatable {
    public var dockAutohide: OriginalValue<Bool>
    public var menuBarHide: OriginalValue<Bool>
    public var menuBarFullscreen: OriginalValue<Bool>
    public var scriptedDockAutohide: Bool?
    public var scriptedMenuBarAutohide: Bool?
    public var wallpapers: [WallpaperSnapshot]

    public init(
        dockAutohide: OriginalValue<Bool> = OriginalValue(present: false, value: nil),
        menuBarHide: OriginalValue<Bool> = OriginalValue(present: false, value: nil),
        menuBarFullscreen: OriginalValue<Bool> = OriginalValue(present: false, value: nil),
        scriptedDockAutohide: Bool? = false,
        scriptedMenuBarAutohide: Bool? = false,
        wallpapers: [WallpaperSnapshot] = []
    ) {
        self.dockAutohide = dockAutohide
        self.menuBarHide = menuBarHide
        self.menuBarFullscreen = menuBarFullscreen
        self.scriptedDockAutohide = scriptedDockAutohide
        self.scriptedMenuBarAutohide = scriptedMenuBarAutohide
        self.wallpapers = wallpapers
    }
}

public final class FakeSystemAdapter: SystemAdapter {
    public var world: FakeWorld
    public var calls: [String] = []
    public var failureInjections: [String: Error] = [:]
    public var onWrite: ((String) throws -> Void)?

    public init(world: FakeWorld = FakeWorld()) {
        self.world = world
    }

    public func readDockAutohide() -> OriginalValue<Bool> {
        world.dockAutohide
    }

    public func readMenuBarKeys() -> (hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) {
        (world.menuBarHide, world.menuBarFullscreen)
    }

    public func readScripted() -> (dock: Bool?, menuBar: Bool?) {
        (world.scriptedDockAutohide, world.scriptedMenuBarAutohide)
    }

    public func readWallpapers() -> [WallpaperSnapshot] {
        world.wallpapers
    }

    public func setDockAutohide(_ v: Bool) throws {
        calls.append("setDockAutohide(\(v))")
        if let err = failureInjections["setDockAutohide"] { throw err }
        try onWrite?("setDockAutohide")
        world.dockAutohide = OriginalValue(present: true, value: v)
        world.scriptedDockAutohide = v
    }

    public func setMenuBarAutohide(_ v: Bool) throws {
        calls.append("setMenuBarAutohide(\(v))")
        if let err = failureInjections["setMenuBarAutohide"] { throw err }
        try onWrite?("setMenuBarAutohide")
        world.scriptedMenuBarAutohide = v
    }

    public func deleteDockAutohideKey() throws {
        calls.append("deleteDockAutohideKey")
        if let err = failureInjections["deleteDockAutohideKey"] { throw err }
        try onWrite?("deleteDockAutohideKey")
        world.dockAutohide = OriginalValue(present: false, value: nil)
    }

    public func setMenuBarKeys(hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) throws {
        calls.append("setMenuBarKeys(hide:\(hide.present ? "\(hide.value as Optional)" : "absent"),fs:\(fullscreen.present ? "\(fullscreen.value as Optional)" : "absent"))")
        if let err = failureInjections["setMenuBarKeys"] { throw err }
        try onWrite?("setMenuBarKeys")
        world.menuBarHide = hide
        world.menuBarFullscreen = fullscreen
    }

    public func setWallpapers(_ wallpapers: [WallpaperSnapshot]) throws {
        calls.append("setWallpapers(\(wallpapers.count))")
        if let err = failureInjections["setWallpapers"] { throw err }
        try onWrite?("setWallpapers")
        world.wallpapers = wallpapers
    }

    public func isStable() -> Bool {
        true
    }
}
