import AppKit
import Combine
import CoreGraphics
import Foundation
import PersonaCore

/// Monitors system power, thermal, display sleep, battery, and fullscreen state to drive Calm Mode (§11.1).
@MainActor
public final class PowerStateMonitor {
    public static let shared = PowerStateMonitor()

    private var config: AppConfig = AppConfig()
    private var screensSleeping = false
    private var batteryLatched = false
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var telemetryCancellable: AnyCancellable?

    public init() {}

    public func start(config: AppConfig = AppConfig()) {
        self.config = config
        guard observers.isEmpty && workspaceObservers.isEmpty else {
            reevaluate()
            return
        }

        let nc = NotificationCenter.default
        observers.append(
            nc.addObserver(
                forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
        )
        observers.append(
            nc.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
        )

        let ws = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(
            ws.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.screensSleeping = true
                    self?.reevaluate()
                }
            }
        )
        workspaceObservers.append(
            ws.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.screensSleeping = false
                    self?.reevaluate()
                }
            }
        )
        workspaceObservers.append(
            ws.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
        )
        workspaceObservers.append(
            ws.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
        )

        telemetryCancellable = AppState.shared.$telemetry.sink { [weak self] _ in
            Task { @MainActor in self?.reevaluate() }
        }

        reevaluate()
    }

    public func updateConfig(_ newConfig: AppConfig) {
        self.config = newConfig
        reevaluate()
    }

    public func stop() {
        let nc = NotificationCenter.default
        for obs in observers {
            nc.removeObserver(obs)
        }
        observers.removeAll()

        let ws = NSWorkspace.shared.notificationCenter
        for obs in workspaceObservers {
            ws.removeObserver(obs)
        }
        workspaceObservers.removeAll()

        telemetryCancellable?.cancel()
        telemetryCancellable = nil
    }

    public func reevaluate() {
        let pInfo = ProcessInfo.processInfo
        let tel = AppState.shared.telemetry
        let thermal = pInfo.thermalState
        let thermalHot = (thermal == .serious || thermal == .critical)
        let envDisable = (pInfo.environment["PERSONA_HUD_ANIMATION"] == "0")

        let inputs = CalmInputs(
            lowPowerMode: pInfo.isLowPowerModeEnabled,
            hasBattery: tel.battery.hasBattery,
            isCharging: tel.battery.isCharging,
            batteryPercent: Int(tel.battery.percent.rounded()),
            previouslyBatteryLatched: batteryLatched,
            screensSleeping: screensSleeping,
            fullscreenAppFrontmost: Self.isFrontmostWindowFullscreen(),
            thermalSeriousOrCritical: thermalHot,
            ambientAnimationEnabled: config.hud.ambientAnimation,
            calmOnBatteryEnabled: config.hud.calmOnBattery,
            envHudAnimationDisabled: envDisable
        )

        let decision = CalmPolicy.decide(inputs)
        batteryLatched = decision.batteryLatched
        if AppState.shared.ambientPaused != decision.calm {
            AppState.shared.ambientPaused = decision.calm
            WebStatePublisher.shared.schedulePublish()
        }
    }

    private static func isFrontmostWindowFullscreen() -> Bool {
        guard let screen = NSScreen.main else { return false }
        let screenSize = screen.frame.size
        guard screenSize.width > 0 && screenSize.height > 0 else { return false }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              frontPID != ownPID else {
            return false
        }

        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for entry in list {
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid == frontPID else { continue }
            guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary else { continue }
            var rect = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDict, &rect) else { continue }
            if rect.width >= screenSize.width * 0.99 && rect.height >= screenSize.height * 0.99 {
                return true
            }
        }
        return false
    }
}
