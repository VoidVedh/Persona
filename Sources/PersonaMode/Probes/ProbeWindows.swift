import AppKit
import CoreGraphics
import Foundation
import PersonaCore
import PersonaKit

/// `--probe windows [--seconds N] [--out f]`
///
/// Starts only the `WindowHostManager` (no snapshot, no system mutation — equivalent to
/// `PERSONA_DRY_RUN=1`), waits, then reports every window owned by this process as seen by the
/// WindowServer (`CGWindowListCopyWindowInfo`) alongside the `NSWindow` introspection values.
/// After `stop()` it reports how many windows remain (must be 0).
public enum ProbeWindows: Probe {
    public static func run(args: [String]) -> Int32 {
        let seconds = ProbeIO.double(of: "--seconds", in: args, default: 2)

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let config = AppConfig()
        let manager = WindowHostManager(config: config, factory: PlaceholderContentFactory())
        manager.start()
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))

        var roles: [Int: String] = [:]
        var introspection: [Int: [String: Any]] = [:]
        var ordered: [(role: String, number: Int)] = []
        for item in manager.orderedEntries {
            let bar = item.entry.bar
            let overlay = item.entry.overlay
            roles[bar.windowNumber] = "bar"
            roles[overlay.windowNumber] = "overlay"
            introspection[bar.windowNumber] = [
                "ignoresMouseEvents": bar.ignoresMouseEvents,
                "canBecomeKey": bar.canBecomeKey,
                "canBecomeMain": bar.canBecomeMain,
                "level": bar.level.rawValue,
                "collectionBehavior": bar.collectionBehavior.rawValue,
                "styleMask": bar.styleMask.rawValue,
                "isOpaque": bar.isOpaque,
                "hasShadow": bar.hasShadow,
                "hidesOnDeactivate": bar.hidesOnDeactivate,
            ]
            introspection[overlay.windowNumber] = [
                "ignoresMouseEvents": overlay.ignoresMouseEvents,
                "canBecomeKey": overlay.canBecomeKey,
                "canBecomeMain": overlay.canBecomeMain,
                "level": overlay.level.rawValue,
                "collectionBehavior": overlay.collectionBehavior.rawValue,
                "styleMask": overlay.styleMask.rawValue,
                "isOpaque": overlay.isOpaque,
                "hasShadow": overlay.hasShadow,
                "hidesOnDeactivate": overlay.hidesOnDeactivate,
            ]
            ordered.append(("bar", bar.windowNumber))
            ordered.append(("overlay", overlay.windowNumber))
        }

        let cgInfo = ownedWindows()
        var windows: [[String: Any]] = []
        for item in ordered {
            var entry: [String: Any] = ["role": item.role, "windowNumber": item.number]
            if let cg = cgInfo[item.number] {
                entry["layer"] = cg["layer"]
                entry["bounds"] = cg["bounds"]
                entry["alpha"] = cg["alpha"]
                entry["onScreen"] = cg["onScreen"]
            }
            for (k, v) in introspection[item.number] ?? [:] { entry[k] = v }
            windows.append(entry)
        }

        let screens: [[String: Any]] = ScreenModel.current().map { screen in
            [
                "id": Int(screen.id),
                "frame": rectDict(screen.frame),
                "safeTop": screen.safeTop,
                "hasNotch": screen.hasNotch,
                "isPrimary": screen.isPrimary,
            ]
        }

        manager.stop()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        let lingering = ownedWindows().filter { roles[$0.key] != nil }
        // `.optionAll` also lists closed windows the WindowServer has not reaped yet; what matters to
        // the user (and the Phase 2 gate) is that none of them is still on screen.
        let remaining = lingering.filter { ($0.value["onScreen"] as? Bool) == true }.count
        let listedAfterStop = lingering.count

        let constants: [String: Int] = [
            "desktopWindow": Int(CGWindowLevelForKey(.desktopWindow)),
            "desktopIconWindow": Int(CGWindowLevelForKey(.desktopIconWindow)),
            "mainMenu": Int(CGWindowLevelForKey(.mainMenuWindow)),
            "statusBar": Int(CGWindowLevelForKey(.statusWindow)),
            "popUpMenu": Int(CGWindowLevelForKey(.popUpMenuWindow)),
        ]

        let result: [String: Any] = [
            "windows": windows,
            "windowsAfterStop": remaining,
            "windowsListedAfterStop": listedAfterStop,
            "constants": constants,
            "screens": screens,
            "expected": [
                "barLevel": WindowLevels.topBar.rawValue,
                "overlayLevel": WindowLevels.desktopOverlay.rawValue,
            ],
        ]
        return ProbeIO.emit(result, args: args)
    }

    private static func rectDict(_ r: CGRect) -> [String: Double] {
        ["x": r.origin.x, "y": r.origin.y, "width": r.size.width, "height": r.size.height]
    }

    /// Windows of this process keyed by `kCGWindowNumber`.
    private static func ownedWindows() -> [Int: [String: Any]] {
        let pid = Int(ProcessInfo.processInfo.processIdentifier)
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return [:]
        }
        var result: [Int: [String: Any]] = [:]
        for info in list {
            guard let owner = info[kCGWindowOwnerPID as String] as? Int, owner == pid,
                  let number = info[kCGWindowNumber as String] as? Int else { continue }
            let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
            result[number] = [
                "layer": info[kCGWindowLayer as String] as? Int ?? -1,
                "bounds": bounds,
                "alpha": info[kCGWindowAlpha as String] as? Double ?? -1,
                "onScreen": info[kCGWindowIsOnscreen as String] as? Bool ?? false,
            ]
        }
        return result
    }
}

/// `--probe windows-of --pid <pid> [--out f]` — counts on-screen windows owned by another process.
/// Used by shell smoke tests to prove a running session's windows appear and disappear.
public enum ProbeWindowsOf: Probe {
    public static func run(args: [String]) -> Int32 {
        let pid = ProbeIO.int(of: "--pid", in: args, default: -1)
        guard pid > 0 else {
            fputs("usage: --probe windows-of --pid <pid>\n", stderr)
            return 1
        }
        let list = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        let mine = list.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid }
        let layers = mine.compactMap { $0[kCGWindowLayer as String] as? Int }.sorted()
        return ProbeIO.emit(["pid": pid, "onScreenCount": mine.count, "layers": layers], args: args)
    }
}
