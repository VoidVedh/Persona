import Foundation
import PersonaCore

public enum ProbeSnapshot: Probe {
    public static func run(args: [String]) -> Int32 {
        var outPath: String?
        var skipAppleScript = false

        var i = 0
        while i < args.count {
            if args[i] == "--out" && i + 1 < args.count {
                outPath = args[i + 1]
                i += 2
            } else if args[i] == "--no-applescript" {
                skipAppleScript = true
                i += 1
            } else {
                i += 1
            }
        }

        let adapter = RealSystemAdapter(skipAppleScript: skipAppleScript)
        let dockAutohide = adapter.readDockAutohide()
        let menuBarKeys = adapter.readMenuBarKeys()
        let scripted = adapter.readScripted()
        let wallpapers = adapter.readWallpapers()

        let snapshot = SystemStateSnapshot(
            dock: DockSnapshot(autohide: dockAutohide),
            menuBar: MenuBarSnapshot(
                hideMenuBar: menuBarKeys.hide,
                visibleInFullscreen: menuBarKeys.fullscreen,
                scriptedAutohide: scripted.menuBar,
                mechanism: "systemEvents"
            ),
            wallpapers: wallpapers
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(snapshot),
              let jsonString = String(data: data, encoding: .utf8) else {
            fputs("Error: Failed to encode SystemStateSnapshot\n", stderr)
            return 1
        }

        print(jsonString)

        if let path = outPath {
            do {
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch {
                fputs("Error writing to \(path): \(error.localizedDescription)\n", stderr)
                return 1
            }
        }

        return 0
    }
}
