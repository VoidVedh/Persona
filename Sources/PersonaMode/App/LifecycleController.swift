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
    private var exitObserver: NSObjectProtocol?
    private var ctlObserver: NSObjectProtocol?

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

        let trusted = AXPermission.shared.isTrusted
        AppState.shared.axTrusted = trusted
        AppState.shared.tilingEnabled = config.tiling.enabled

        // Inject AX window title provider into FocusTracker
        FocusTracker.shared.titleProvider = AXFocusTitleProvider()

        // Start Telemetry & Tracking Services
        TelemetryStore.shared.start()
        FocusTracker.shared.start()
        SpaceProvider.shared.start()
        NowPlayingService.shared.start()

        // Wire CommandRouter handlers
        wireCommandRouter()

        // Wire Quit notification
        exitObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("dev.persona.mode.exit"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.exitPersona()
            }
        }

        // Wire DistributedNotificationCenter `--ctl <cmd>` channel
        ctlObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("dev.persona.mode.command"),
            object: nil,
            queue: .main
        ) { notif in
            guard let raw = notif.userInfo?["cmd"] as? String,
                  let cmd = PersonaCommand.from(string: raw) else { return }
            Task { @MainActor in
                CommandRouter.shared.send(cmd)
            }
        }

        let factory = PersonaContentFactory(onQuit: { [weak self] in
            self?.exitPersona()
        })
        let host = WindowHostManager(config: config, factory: factory)
        windowHost = host
        host.start()

        // Start Active-Window Border & Tiling Engine (Phase 4)
        BorderController.shared.config = config
        BorderController.shared.start()

        TilingController.shared.config = config
        TilingController.shared.journal = FrameJournal(supportDir: store.supportDir)
        if let sys = TilingController.shared.provider as? SystemAXWindowProvider {
            sys.configFloatApps = config.tiling.floatApps
        }
        TilingController.shared.start()

        if trusted {
            AXWindowObserver.shared.start()
        }

        AXPermission.shared.startPolling(interval: 1.0) { newTrust in
            Task { @MainActor in
                AppState.shared.axTrusted = newTrust
                if newTrust {
                    AXWindowObserver.shared.start()
                } else {
                    AXWindowObserver.shared.stop()
                }
                EventBus.shared.publish(.axTrustChanged(newTrust))
            }
        }

        // Module teardown runs *after* Dock/Menu Bar/Wallpaper are restored (I5).
        restore.registerModuleStopHook { [weak self] in
            LifecycleController.runOnMain { self?.stopModules() }
        }
    }

    private func wireCommandRouter() {
        let router = CommandRouter.shared
        router.onTile = {
            TilingController.shared.retileAll()
        }
        router.onToggleFloat = {
            TilingController.shared.toggleFloatFocused()
        }
        router.onReloadTheme = { [weak self] in
            self?.reloadTheme()
        }
        router.onToggleDarkHour = {
            AppState.shared.toggleDarkHour()
        }
        router.onSwitchSpace = { n in
            SpaceProvider.shared.switchTo(spaceIndex: n)
        }
        router.onExitPersona = { [weak self] in
            self?.exitPersona()
        }
        router.onPanic = { [weak self] in
            _ = self?.restoreService?.restoreAll(reason: .panic)
            exit(0)
        }
    }

    public func reloadTheme() {
        let userConfig = store.supportDir.appendingPathComponent("config.json")
        let (loaded, warnings) = AppConfig.load(userFile: userConfig)
        config = loaded
        for warning in warnings { fputs("config: \(warning)\n", stderr) }

        windowHost?.updateConfig(loaded)
        BorderController.shared.updateConfig(loaded)
        TilingController.shared.updateConfig(loaded)
    }

    private func stopModules() {
        if let obs = exitObserver {
            NotificationCenter.default.removeObserver(obs)
            exitObserver = nil
        }
        if let ctl = ctlObserver {
            DistributedNotificationCenter.default().removeObserver(ctl)
            ctlObserver = nil
        }

        AXPermission.shared.stopPolling()
        AXWindowObserver.shared.stop()

        TilingController.shared.stop()
        TilingController.shared.restoreFrames()

        BorderController.shared.stop()

        windowHost?.stop()
        windowHost = nil

        TelemetryStore.shared.stop()
        FocusTracker.shared.stop()
        SpaceProvider.shared.stop()
        NowPlayingService.shared.stop()
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
