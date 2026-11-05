import Foundation
import PersonaCore
import PersonaKit

public enum WebStateSuite {
    public static func run(_ t: Harness) {
        t.suite("webstate") {
            let bar = BarState()
            let hud = HudState()
            let launcher = LauncherState()

            do {
                let barJSON = try WebStateJSON.encode(bar, pretty: true)
                let decodedBar = try WebStateJSON.decode(BarState.self, from: barJSON)
                t.expectEqual(decodedBar, bar, "BarState round-trips through sorted-key JSON")

                let hudJSON = try WebStateJSON.encode(hud, pretty: true)
                let decodedHud = try WebStateJSON.decode(HudState.self, from: hudJSON)
                t.expectEqual(decodedHud, hud, "HudState round-trips through sorted-key JSON")

                let launcherJSON = try WebStateJSON.encode(launcher, pretty: true)
                let decodedLauncher = try WebStateJSON.decode(LauncherState.self, from: launcherJSON)
                t.expectEqual(decodedLauncher, launcher, "LauncherState round-trips through sorted-key JSON")

                if let resDir = ResourceLocator.resourceDirectory() {
                    let fixDir = resDir.appendingPathComponent("webui/fixtures", isDirectory: true)

                    let barFile = try String(contentsOf: fixDir.appendingPathComponent("bar.default.json"), encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let barFromFix = try WebStateJSON.decode(BarState.self, from: barFile)
                    let barReencoded = try WebStateJSON.encode(barFromFix, pretty: true)
                    t.expectEqual(barReencoded, barFile, "bar.default.json decodes and re-encodes identically")

                    let notchFile = try String(contentsOf: fixDir.appendingPathComponent("bar.notch.json"), encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let notchFromFix = try WebStateJSON.decode(BarState.self, from: notchFile)
                    let notchReencoded = try WebStateJSON.encode(notchFromFix, pretty: true)
                    t.expectEqual(notchReencoded, notchFile, "bar.notch.json decodes and re-encodes identically")

                    let hudFile = try String(contentsOf: fixDir.appendingPathComponent("hud.afterschool.json"), encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let hudFromFix = try WebStateJSON.decode(HudState.self, from: hudFile)
                    let hudReencoded = try WebStateJSON.encode(hudFromFix, pretty: true)
                    t.expectEqual(hudReencoded, hudFile, "hud.afterschool.json decodes and re-encodes identically")

                    let darkFile = try String(contentsOf: fixDir.appendingPathComponent("hud.darkhour.json"), encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let darkFromFix = try WebStateJSON.decode(HudState.self, from: darkFile)
                    let darkReencoded = try WebStateJSON.encode(darkFromFix, pretty: true)
                    t.expectEqual(darkReencoded, darkFile, "hud.darkhour.json decodes and re-encodes identically")

                    let launcherFile = try String(contentsOf: fixDir.appendingPathComponent("launcher.default.json"), encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let launcherFromFix = try WebStateJSON.decode(LauncherState.self, from: launcherFile)
                    let launcherReencoded = try WebStateJSON.encode(launcherFromFix, pretty: true)
                    t.expectEqual(launcherReencoded, launcherFile, "launcher.default.json decodes and re-encodes identically")
                } else {
                    t.fail("ResourceLocator.resourceDirectory() returned nil")
                }
            } catch {
                t.fail("WebStateSuite error: \(error)")
            }
        }
    }
}

