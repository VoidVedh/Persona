import AppKit
import Foundation
import PersonaKit

public enum ProbeFocus: Probe {
    public static func run(args: [String]) -> Int32 {
        let seconds = ProbeIO.double(of: "--seconds", in: args, default: 2.0)
        let tracker = FocusTracker.shared
        tracker.start()

        RunLoop.main.run(until: Date().addingTimeInterval(seconds))

        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = AppState.shared.focusedApp
        let title = AppState.shared.focusedTitle
        let bundleId = frontApp?.bundleIdentifier ?? ""

        tracker.stop()

        let result: [String: Any] = [
            "app": appName,
            "title": title,
            "bundleId": bundleId
        ]
        return ProbeIO.emit(result, args: args)
    }
}
