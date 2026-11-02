import AppKit
import Foundation
import PersonaCore
import PersonaKit

@MainActor
public final class LifecycleController {
    public static let shared = LifecycleController()

    public private(set) var store: StateStore
    public private(set) var adapter: SystemAdapter
    /// Adapter used exclusively for stale-session recovery. Restoring original values is always
    /// performed for real, even when the session itself runs in dry-run mode (I2).
    private let recoveryAdapter: SystemAdapter
    public private(set) var restoreService: RestoreService?
    public private(set) var heartbeatPump: HeartbeatPump?
    public private(set) var sessionLock: SessionLock?
    public private(set) var windowHost: WindowHostManager?
    public private(set) var config: AppConfig = AppConfig()
    public private(set) var isRunning = false

    public init(
        store: StateStore = StateStore(),
        adapter: SystemAdapter? = nil
    ) {
        self.store = store
        if let customAdapter = adapter {
            self.adapter = customAdapter
            self.recoveryAdapter = customAdapter
        } else {
            let isDryRun = ProcessInfo.processInfo.environment["PERSONA_DRY_RUN"] == "1"
            let isPhase1Demo = ProcessInfo.processInfo.environment["PERSONA_PHASE1_DEMO"] == "1"
            let real = RealSystemAdapter()
            self.recoveryAdapter = real
            if isDryRun || !isPhase1Demo {
                self.adapter = DryRunAdapter(underlying: real)
            } else {
                self.adapter = real
            }
        }
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        do {
            // I2: if a previous session died while mutating, restore it for real BEFORE snapshotting.
            _ = try RecoveryManager.recoverIfStale(store: store, adapter: recoveryAdapter)
            let state = try SnapshotService.begin(store: store, lock: &sessionLock, adapter: adapter, mode: .overlay)
            let restore = RestoreService(store: store, adapter: adapter)
            self.restoreService = restore
            RestoreService.shared = restore

            let pump = HeartbeatPump(supportDir: store.supportDir)
            pump.start()
            self.heartbeatPump = pump

            GuardianLauncher.spawn(supportDir: store.supportDir)

            // If PERSONA_PHASE1_DEMO=1, apply dock & menuBar autohide mutations
            if ProcessInfo.processInfo.environment["PERSONA_PHASE1_DEMO"] == "1" {
                let mutator = SystemMutator(store: store, adapter: adapter, state: state)
                try mutator.apply(.dockAutohide(true))
                try mutator.apply(.menuBarAutohide(true))
            }

            startWindows(restore: restore)
        } catch {
            fputs("LifecycleController start failed: \(error)\n", stderr)
            _ = restoreService?.restoreAll(reason: .exception)
            if error as? SnapshotServiceError == .sessionAlreadyActive {
                // Another Persona Mode session owns the system state; never touch it from here.
                NSApp.terminate(nil)
            }
        }
    }

    private func startWindows(restore: RestoreService) {
        let userConfig = store.supportDir.appendingPathComponent("config.json")
        let (loaded, warnings) = AppConfig.load(userFile: userConfig)
        config = loaded
        for warning in warnings { fputs("config: \(warning)\n", stderr) }

        let host = WindowHostManager(config: config, factory: PlaceholderContentFactory())
        windowHost = host
        host.start()

        // Module teardown runs *after* Dock/Menu Bar/Wallpaper are restored (I5).
        restore.registerModuleStopHook { [weak self] in
            LifecycleController.runOnMain { self?.stopModules() }
        }
    }

    private func stopModules() {
        windowHost?.stop()
        windowHost = nil
    }

    /// Return-to-macOS: restore synchronously, then terminate (also reached from bar QUIT, Phase 3).
    public func exitPersona() {
        _ = restoreService?.restoreAll(reason: .userQuit)
        NSApp.terminate(nil)
    }

    /// Runs `block` on the main thread without deadlocking when already there.
    nonisolated static func runOnMain(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { block() }
        } else {
            DispatchQueue.main.sync { MainActor.assumeIsolated { block() } }
        }
    }
}
