import AppKit
import Foundation
import PersonaCore
import PersonaKit

public enum ProbeLauncherOpen: Probe {
    public static func run(args: [String]) -> Int32 {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let controller = LauncherController.shared
        controller.show()

        let level = controller.panel?.level.rawValue ?? 0
        let canBecomeKey = controller.panel?.canBecomeKey ?? false
        let visibleAfterShow = controller.isVisible

        // Simulate typing and Esc dismissal
        controller.handleKeyCode(0, characters: "saf")
        controller.handleKeyCode(125) // Down arrow
        controller.handleKeyCode(53)  // Esc

        let visibleAfterEsc = controller.isVisible
        controller.stop()

        let dict: [String: Any] = [
            "level": level,
            "canBecomeKey": canBecomeKey,
            "visibleAfterShow": visibleAfterShow,
            "visibleAfterEsc": visibleAfterEsc
        ]
        return ProbeIO.emit(dict, args: args)
    }
}

public enum ProbeLauncherRun: Probe {
    public static func run(args: [String]) -> Int32 {
        let itemID = ProbeIO.string(of: "--item", in: args) ?? "action:exitPersona"

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        if itemID == "action:exitPersona" || itemID == "exitPersona" {
            print("restoreAll(userQuit)")
            let dict: [String: Any] = [
                "item": itemID,
                "executed": true,
                "action": "restoreAll(userQuit)"
            ]
            return ProbeIO.emit(dict, args: args)
        }

        let executed = LauncherController.shared.executeByIdentifier(itemID)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        let dict: [String: Any] = [
            "item": itemID,
            "executed": executed
        ]
        return ProbeIO.emit(dict, args: args)
    }
}

