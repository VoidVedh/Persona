import Foundation

public enum SnapshotServiceError: Error, Equatable {
    case sessionAlreadyActive
    case lockAcquisitionFailed
}

public final class SnapshotService {
    public private(set) var lock: SessionLock?
    public static var activeLock: SessionLock?

    public init() {}

    @discardableResult
    public func begin(
        store: StateStore,
        lock: SessionLock? = nil,
        adapter: SystemAdapter,
        mode: WallpaperMode = .overlay
    ) throws -> StateFile {
        // I2: Check if stale active state or unheld session.lock exists
        let existingState = store.load()
        let lockURL = store.supportDir.appendingPathComponent("session.lock")
        let lockExists = FileManager.default.fileExists(atPath: lockURL.path)
        let lockHeldByOther = SessionLock.isHeldByOther(dir: store.supportDir)

        if lockHeldByOther {
            throw SnapshotServiceError.sessionAlreadyActive
        }

        let isStale = (existingState?.active == true) || (lockExists && !lockHeldByOther)
        if isStale {
            _ = try RecoveryManager.recoverIfStale(store: store, adapter: adapter)
        }

        // Read pristine snapshot via adapter
        let dockSnap = DockSnapshot(autohide: adapter.readDockAutohide())
        let (hideKey, fsKey) = adapter.readMenuBarKeys()
        let (_, scriptedMB) = adapter.readScripted()
        let menuBarSnap = MenuBarSnapshot(
            hideMenuBar: hideKey,
            visibleInFullscreen: fsKey,
            scriptedAutohide: scriptedMB ?? false,
            mechanism: "systemEvents"
        )
        let wallpapersSnap = adapter.readWallpapers()

        var state = StateFile(
            schemaVersion: 1,
            sessionId: UUID().uuidString,
            active: true,
            appPid: ProcessInfo.processInfo.processIdentifier,
            createdAt: Date(),
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            wallpaperMode: mode,
            snapshot: SystemStateSnapshot(dock: dockSnap, menuBar: menuBarSnap, wallpapers: wallpapersSnap),
            ledger: RestoreLedger(),
            phase: .snapshotted
        )

        // I1: Snapshot before mutate - write state durably before taking lock or proceeding
        try store.save(state)

        // Acquire session lock
        if let passedLock = lock {
            self.lock = passedLock
        } else {
            guard let newLock = SessionLock(dir: store.supportDir) else {
                throw SnapshotServiceError.lockAcquisitionFailed
            }
            self.lock = newLock
        }
        SnapshotService.activeLock = self.lock

        state.phase = .armed
        try store.save(state)

        return state
    }

    @discardableResult
    public static func begin(
        store: StateStore,
        lock: SessionLock? = nil,
        adapter: SystemAdapter,
        mode: WallpaperMode = .overlay
    ) throws -> StateFile {
        let service = SnapshotService()
        return try service.begin(store: store, lock: lock, adapter: adapter, mode: mode)
    }

    @discardableResult
    public static func begin(
        store: StateStore,
        lock: inout SessionLock?,
        adapter: SystemAdapter,
        mode: WallpaperMode = .overlay
    ) throws -> StateFile {
        let service = SnapshotService()
        let state = try service.begin(store: store, lock: lock, adapter: adapter, mode: mode)
        lock = service.lock
        return state
    }
}
