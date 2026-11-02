import Foundation

public enum RestoreReason: String, Codable, Equatable {
    case userQuit
    case exception
    case signal
    case powerOff
    case panic
    case api
    case staleRecovery
}

public struct RestoreStepReport: Equatable {
    public let step: String
    public let success: Bool
    public let error: String?

    public init(step: String, success: Bool, error: String? = nil) {
        self.step = step
        self.success = success
        self.error = error
    }
}

public struct RestoreReport: Equatable {
    public let reason: RestoreReason
    public let steps: [RestoreStepReport]
    public let verified: Bool

    public init(reason: RestoreReason, steps: [RestoreStepReport], verified: Bool) {
        self.reason = reason
        self.steps = steps
        self.verified = verified
    }
}

public final class RestoreService {
    public static var shared: RestoreService?

    public let store: StateStore
    public let adapter: SystemAdapter
    public private(set) var hasRestored = false
    public var onStopModules: [() -> Void] = []

    public init(store: StateStore, adapter: SystemAdapter) {
        self.store = store
        self.adapter = adapter
    }

    public func registerModuleStopHook(_ hook: @escaping () -> Void) {
        onStopModules.append(hook)
    }

    @discardableResult
    public func restoreAll(reason: RestoreReason) -> RestoreReport {
        if hasRestored && !store.stateFileExists {
            return RestoreReport(reason: reason, steps: [RestoreStepReport(step: "idempotent", success: true)], verified: true)
        }

        var steps: [RestoreStepReport] = []

        guard let state = store.load() else {
            // No state on disk: fallback restore defaults
            do {
                try adapter.setDockAutohide(false)
                try adapter.deleteDockAutohideKey()
                steps.append(RestoreStepReport(step: "dock-fallback", success: true))
            } catch {
                steps.append(RestoreStepReport(step: "dock-fallback", success: false, error: "\(error)"))
            }

            do {
                try adapter.setMenuBarAutohide(false)
                try adapter.setMenuBarKeys(
                    hide: OriginalValue(present: false, value: nil),
                    fullscreen: OriginalValue(present: false, value: nil)
                )
                steps.append(RestoreStepReport(step: "menubar-fallback", success: true))
            } catch {
                steps.append(RestoreStepReport(step: "menubar-fallback", success: false, error: "\(error)"))
            }

            store.delete()
            let lockURL = store.supportDir.appendingPathComponent("session.lock")
            _ = unlink(lockURL.path)
            hasRestored = true
            return RestoreReport(reason: reason, steps: steps, verified: true)
        }

        // 1. Flush phase
        var flushingState = state
        flushingState.phase = .restoring
        try? store.save(flushingState)
        steps.append(RestoreStepReport(step: "phase-flush", success: true))

        // 2. Critical system state: Dock -> Menu Bar -> Wallpaper (I5, independent)
        // Dock
        let origDock = state.snapshot.dock.autohide
        do {
            if origDock.present {
                try adapter.setDockAutohide(origDock.value ?? false)
            } else {
                try adapter.setDockAutohide(false)
                try adapter.deleteDockAutohideKey()
            }
            steps.append(RestoreStepReport(step: "dock", success: true))
        } catch {
            steps.append(RestoreStepReport(step: "dock", success: false, error: "\(error)"))
        }

        // Menu Bar
        let origMB = state.snapshot.menuBar
        do {
            if let scripted = origMB.scriptedAutohide {
                try adapter.setMenuBarAutohide(scripted)
            } else {
                try adapter.setMenuBarAutohide(false)
            }
            try adapter.setMenuBarKeys(hide: origMB.hideMenuBar, fullscreen: origMB.visibleInFullscreen)
            steps.append(RestoreStepReport(step: "menubar", success: true))
        } catch {
            steps.append(RestoreStepReport(step: "menubar", success: false, error: "\(error)"))
        }

        // Wallpaper
        do {
            if state.wallpaperMode == .system {
                try adapter.setWallpapers(state.snapshot.wallpapers)
            }
            steps.append(RestoreStepReport(step: "wallpaper", success: true))
        } catch {
            steps.append(RestoreStepReport(step: "wallpaper", success: false, error: "\(error)"))
        }

        // 3. Stop modules
        for hook in onStopModules {
            hook()
        }
        steps.append(RestoreStepReport(step: "modules-stop", success: true))

        // 4. Temp / terminal cleanup
        for entry in state.ledger.pendingOrApplied {
            switch entry.mutation {
            case .tempDir(let path):
                if RecoveryManager.isSafeToDelete(path: path, supportDir: store.supportDir) {
                    try? FileManager.default.removeItem(atPath: path)
                }
            case .terminalProfile:
                break
            case .dockAutohide, .menuBarAutohide, .systemWallpaper:
                break
            }
        }
        steps.append(RestoreStepReport(step: "temp-cleanup", success: true))

        // 5. Verify
        let currentDock = adapter.readDockAutohide()
        let (currentHide, currentFS) = adapter.readMenuBarKeys()

        let dockMatches = (currentDock == origDock)
        let hideMatches = (currentHide == origMB.hideMenuBar)
        let fsMatches = (currentFS == origMB.visibleInFullscreen)
        let verified = dockMatches && hideMatches && fsMatches

        if verified {
            var finalState = state
            finalState.active = false
            finalState.phase = .restored
            store.delete()

            // Remove heartbeat, windows.json, and guardian lock metadata
            try? FileManager.default.removeItem(at: store.supportDir.appendingPathComponent("heartbeat"))
            try? FileManager.default.removeItem(at: store.supportDir.appendingPathComponent("windows.json"))
            try? FileManager.default.removeItem(at: store.supportDir.appendingPathComponent("session.lock.guardian"))

            // Remove session.lock LAST
            let lockURL = store.supportDir.appendingPathComponent("session.lock")
            _ = unlink(lockURL.path)

            // Remove supportDir if now empty
            if let items = try? FileManager.default.contentsOfDirectory(atPath: store.supportDir.path), items.isEmpty {
                _ = rmdir(store.supportDir.path)
            }

            hasRestored = true
            steps.append(RestoreStepReport(step: "verify", success: true))
        } else {
            var degradedState = state
            degradedState.phase = .degraded
            try? store.save(degradedState)
            steps.append(RestoreStepReport(step: "verify", success: false, error: "Verification mismatch: dockMatches=\(dockMatches), hideMatches=\(hideMatches), fsMatches=\(fsMatches)"))
        }

        return RestoreReport(reason: reason, steps: steps, verified: verified)
    }
}
