import AppKit
import Foundation
import PersonaCore

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
        } catch {
            fputs("LifecycleController start failed: \(error)\n", stderr)
            _ = restoreService?.restoreAll(reason: .exception)
        }
    }
}
