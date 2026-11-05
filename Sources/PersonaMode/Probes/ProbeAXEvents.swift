import AppKit
import Foundation
import PersonaCore
import PersonaKit

public enum ProbeAXEvents: Probe {
    public static func run(args: [String]) -> Int32 {
        let seconds = ProbeIO.double(of: "--seconds", in: args, default: 2.0)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        var recorded: [[String: Any]] = []
        let sub = EventBus.shared.subscribe { event in
            let desc: String
            switch event {
            case .windowCreated(let id): desc = "windowCreated:\(id)"
            case .windowDestroyed(let id): desc = "windowDestroyed:\(id)"
            case .focusChanged(let pid, let wid): desc = "focusChanged:pid=\(pid),wid=\(wid ?? 0)"
            case .frameChangedExternally(let wid, _): desc = "frameChanged:\(wid)"
            case .spaceChanged: desc = "spaceChanged"
            case .screensChanged: desc = "screensChanged"
            case .axTrustChanged(let t): desc = "axTrustChanged:\(t)"
            case .tileRequested: desc = "tileRequested"
            case .reloadThemeRequested: desc = "reloadThemeRequested"
            }
            recorded.append(["event": desc])
        }

        AXWindowObserver.shared.start()
        if seconds > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        }
        AXWindowObserver.shared.stop()
        EventBus.shared.unsubscribe(sub)

        let dict: [String: Any] = [
            "trusted": AXPermission.shared.isTrusted,
            "count": recorded.count,
            "events": recorded
        ]
        return ProbeIO.emit(dict, args: args)
    }
}

