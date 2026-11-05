import AppKit
import Foundation
import PersonaCore
import PersonaKit
import WebKit

public enum WebSurfaceSuite {
    public static func run(_ t: Harness) {
        t.suite("websurface") {
            // 1. Pure WebIntent.decode table test
            let validExit = WebIntent.decode(
                body: ["v": 1, "type": "exit"],
                scheme: "persona"
            )
            t.expectEqual(validExit, .exit, "decodes valid exit intent")

            let validSpace = WebIntent.decode(
                body: ["v": 1, "type": "switchSpace", "payload": ["n": 3]],
                scheme: "persona"
            )
            t.expectEqual(validSpace, .switchSpace(3), "decodes valid switchSpace(3)")

            let invalidSpace = WebIntent.decode(
                body: ["v": 1, "type": "switchSpace", "payload": ["n": 99]],
                scheme: "persona"
            )
            t.expect(invalidSpace == nil, "rejects out-of-range space 99")

            let validActivate = WebIntent.decode(
                body: ["v": 1, "type": "launcherActivate", "payload": ["index": 2, "reveal": true]],
                scheme: "persona"
            )
            t.expectEqual(validActivate, .launcherActivate(2, reveal: true), "decodes launcherActivate")

            let validHover = WebIntent.decode(
                body: ["v": 1, "type": "launcherHover", "payload": ["index": 5]],
                scheme: "persona"
            )
            t.expectEqual(validHover, .launcherHover(5), "decodes launcherHover")

            let wrongScheme = WebIntent.decode(
                body: ["v": 1, "type": "exit"],
                scheme: "https"
            )
            t.expect(wrongScheme == nil, "rejects non-persona scheme")

            let unknownType = WebIntent.decode(
                body: ["v": 1, "type": "execShell", "payload": ["cmd": "rm -rf"]],
                scheme: "persona"
            )
            t.expect(unknownType == nil, "rejects unwhitelisted intent type")

            var oversized: [String: Any] = ["v": 1, "type": "exit"]
            for i in 0..<25 {
                oversized["k\(i)"] = i
            }
            t.expect(
                WebIntent.decode(body: oversized, scheme: "persona") == nil,
                "rejects oversized message envelope"
            )

            // 2. MainActor WebSurfaceView & WebBridge lifecycle tests
            MainActor.assumeIsolated {
                runMainActorTests(t)
            }
        }
    }

    @MainActor
    private static func runMainActorTests(_ t: Harness) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        // Patch queue test before ready
        let bridge = WebBridge(surface: .topbar)
        t.expect(!bridge.isReady, "bridge starts not ready")
        bridge.publish(["focusedApp": "FIRST", "calm": false])
        bridge.publish(["focusedApp": "SECOND"])
        t.expectEqual(bridge.pendingPatch["focusedApp"] as? String, "SECOND", "latest patch key wins while queued")
        t.expectEqual(bridge.pendingPatch["calm"] as? Bool, false, "earlier distinct key preserved in queue")
        bridge.markReady()
        t.expect(bridge.isReady, "bridge isReady == true after markReady()")
        t.expect(bridge.pendingPatch.isEmpty, "pendingPatch flushed on markReady()")

        // WebSurfaceView configuration & teardown retain-cycle test
        weak var weakView: WebSurfaceView?
        weak var weakBridge: WebBridge?

        autoreleasepool {
            let surface = WebSurfaceView(surface: .topbar, interactive: true, debug: false)
            weakView = surface
            weakBridge = surface.bridge

            t.expect(!surface.configuration.websiteDataStore.isPersistent, "websiteDataStore is nonPersistent")
            t.expectEqual(surface.value(forKey: "drawsBackground") as? Bool, false, "drawsBackground == false")
            t.expect(!surface.acceptsFirstResponder, "acceptsFirstResponder == false")
            t.expect(surface.acceptsFirstMouse(for: nil), "interactive surface acceptsFirstMouse == true")

            let hudSurface = WebSurfaceView(surface: .hud, interactive: false, debug: false)
            t.expect(!hudSurface.acceptsFirstMouse(for: nil), "non-interactive HUD surface acceptsFirstMouse == false")
            hudSurface.teardown()

            surface.teardown()
        }

        t.expect(weakBridge == nil, "WebBridge deallocated after teardown() (no script handler retain cycle)")
        _ = weakView
    }
}

