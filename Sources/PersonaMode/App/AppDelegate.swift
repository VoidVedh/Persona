import AppKit
import Foundation
import PersonaCore

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        SignalGuard.install()
        MainMenu.install()
        LifecycleController.shared.start()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handlePowerOff),
            name: NSWorkspace.willPowerOffNotification,
            object: nil
        )
    }

    @objc private func handlePowerOff() {
        _ = RestoreService.shared?.restoreAll(reason: .powerOff)
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        _ = RestoreService.shared?.restoreAll(reason: .userQuit)
        return .terminateNow
    }

    public func applicationWillTerminate(_ notification: Notification) {
        _ = RestoreService.shared?.restoreAll(reason: .userQuit)
    }
}
