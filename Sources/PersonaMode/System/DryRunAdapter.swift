import Foundation
import os
import PersonaCore

public final class DryRunAdapter: SystemAdapter {
    private let underlying: SystemAdapter
    private let logger = Logger(subsystem: "dev.persona.mode", category: "DryRun")

    public init(underlying: SystemAdapter) {
        self.underlying = underlying
    }

    public func readDockAutohide() -> OriginalValue<Bool> {
        underlying.readDockAutohide()
    }

    public func readMenuBarKeys() -> (hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) {
        underlying.readMenuBarKeys()
    }

    public func readScripted() -> (dock: Bool?, menuBar: Bool?) {
        underlying.readScripted()
    }

    public func readWallpapers() -> [WallpaperSnapshot] {
        underlying.readWallpapers()
    }

    public func setDockAutohide(_ v: Bool) throws {
        logger.info("DRYRUN: set dock autohide=\(v, privacy: .public)")
        print("DRYRUN: set dock autohide=\(v)")
    }

    public func setMenuBarAutohide(_ v: Bool) throws {
        logger.info("DRYRUN: set menu bar autohide=\(v, privacy: .public)")
        print("DRYRUN: set menu bar autohide=\(v)")
    }

    public func deleteDockAutohideKey() throws {
        logger.info("DRYRUN: delete dock autohide key")
        print("DRYRUN: delete dock autohide key")
    }

    public func setMenuBarKeys(hide: OriginalValue<Bool>, fullscreen: OriginalValue<Bool>) throws {
        let hideDesc = hide.present ? "\(hide.value as Optional)" : "absent"
        let fsDesc = fullscreen.present ? "\(fullscreen.value as Optional)" : "absent"
        logger.info("DRYRUN: set menu bar keys: hide=\(hideDesc, privacy: .public), fullscreen=\(fsDesc, privacy: .public)")
        print("DRYRUN: set menu bar keys: hide=\(hideDesc), fullscreen=\(fsDesc)")
    }

    public func setWallpapers(_ wallpapers: [WallpaperSnapshot]) throws {
        logger.info("DRYRUN: set wallpapers count=\(wallpapers.count, privacy: .public)")
        print("DRYRUN: set wallpapers count=\(wallpapers.count)")
    }

    public func isStable() -> Bool {
        underlying.isStable()
    }
}
