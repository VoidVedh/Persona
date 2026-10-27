import Foundation

public final class RecoveryManager {
    public init() {}

    public static func isSafeToDelete(path: String, supportDir: URL) -> Bool {
        let stdPath = URL(fileURLWithPath: path).standardized.path
        let stdSupport = supportDir.standardized.path
        let tmpDir = NSTemporaryDirectory()
        let personaTmp = URL(fileURLWithPath: tmpDir).appendingPathComponent("PersonaMode").standardized.path

        // Path cannot be root or general system folders
        if stdPath == "/" || stdPath == "/tmp" || stdPath == "/var" || stdPath == "/Users" || stdPath == "/System" {
            return false
        }

        // Must be strictly inside personaTmp or supportDir
        if stdPath.hasPrefix(personaTmp) && stdPath != personaTmp {
            return true
        }
        if stdPath.hasPrefix(stdSupport) && stdPath != stdSupport {
            return true
        }
        return false
    }

    @discardableResult
    public static func recoverIfStale(store: StateStore, adapter: SystemAdapter) throws -> Bool {
        // If locked by another running process, do NOT recover
        if SessionLock.isHeldByOther(dir: store.supportDir) {
            return false
        }

        let state = store.load()
        let lockURL = store.supportDir.appendingPathComponent("session.lock")
        let lockExists = FileManager.default.fileExists(atPath: lockURL.path)

        let isStale = (state?.active == true) || lockExists || (state != nil && state?.phase == .restoring)
        guard isStale else {
            return false
        }

        try recover(store: store, adapter: adapter)
        return true
    }

    public static func recover(store: StateStore, adapter: SystemAdapter) throws {
        let lockURL = store.supportDir.appendingPathComponent("session.lock")

        guard let state = store.load() else {
            // Missing or corrupt state file: fail open to visible defaults
            try? adapter.setDockAutohide(false)
            try? adapter.deleteDockAutohideKey()
            try? adapter.setMenuBarAutohide(false)
            try? adapter.setMenuBarKeys(
                hide: OriginalValue(present: false, value: nil),
                fullscreen: OriginalValue(present: false, value: nil)
            )
            store.delete()
            if !SessionLock.isHeldByOther(dir: store.supportDir) {
                _ = unlink(lockURL.path)
            }
            return
        }

        var recoveringState = state
        recoveringState.phase = .restoring
        try? store.save(recoveringState)

        // 1. Dock restoration
        let origDock = state.snapshot.dock.autohide
        if origDock.present {
            try adapter.setDockAutohide(origDock.value ?? false)
        } else {
            try adapter.setDockAutohide(false)
            try adapter.deleteDockAutohideKey()
        }

        // 2. Menu Bar restoration
        let origMB = state.snapshot.menuBar
        if let scripted = origMB.scriptedAutohide {
            try adapter.setMenuBarAutohide(scripted)
        } else {
            try adapter.setMenuBarAutohide(false)
        }
        try adapter.setMenuBarKeys(hide: origMB.hideMenuBar, fullscreen: origMB.visibleInFullscreen)

        // 3. Wallpaper restoration (only system mode)
        if state.wallpaperMode == .system {
            try adapter.setWallpapers(state.snapshot.wallpapers)
        }

        // 4. Ledger cleanup (temp dirs, terminal profiles)
        for entry in state.ledger.pendingOrApplied {
            switch entry.mutation {
            case .tempDir(let path):
                if isSafeToDelete(path: path, supportDir: store.supportDir) {
                    try? FileManager.default.removeItem(atPath: path)
                }
            case .terminalProfile:
                break
            case .dockAutohide, .menuBarAutohide, .systemWallpaper:
                break
            }
            recoveringState.ledger.markRestored(entry.id)
        }

        // 5. Verification
        let currentDock = adapter.readDockAutohide()
        let (currentHide, currentFS) = adapter.readMenuBarKeys()

        let dockMatches = (currentDock == origDock)
        let hideMatches = (currentHide == origMB.hideMenuBar)
        let fsMatches = (currentFS == origMB.visibleInFullscreen)

        if dockMatches && hideMatches && fsMatches {
            recoveringState.active = false
            recoveringState.phase = .restored
            store.delete()
            if !SessionLock.isHeldByOther(dir: store.supportDir) {
                _ = unlink(lockURL.path)
            }
        } else {
            recoveringState.phase = .degraded
            try? store.save(recoveringState)
        }
    }
}
