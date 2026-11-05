import AppKit
import CoreGraphics
import Foundation
import PersonaCore
import PersonaKit

public enum LayoutSuite {
    public static func run(_ t: Harness) {
        t.suite("layout") {
            // 1. 1 window fills usable
            let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
            let bar = BarInset(marginTop: 6, height: 38)
            let gaps = Gaps(outer: 8, inner: 8)

            let frames1 = LayoutEngine.layout(ids: [100], screen: screen, bar: bar, gaps: gaps)
            t.expectEqual(frames1.count, 1, "1 window produces 1 frame")
            if let f = frames1[100] {
                let expectedUsable = CGRect(
                    x: 8,
                    y: 6 + 38 + 8,
                    width: 1512 - 16,
                    height: 982 - (6 + 38 + 8) - 8
                ).integral
                t.expectEqual(f, expectedUsable, "1 window fills usable rect exactly")
                t.expectEqual(f.minX, 8, "1 window minX == 8")
                t.expectEqual(f.minY, 52, "1 window minY == 52 (6 + 38 + 8)")
            } else {
                t.fail("missing window 100")
            }

            // 2. 2 windows dwindle
            let frames2 = LayoutEngine.layout(ids: [1, 2], screen: screen, bar: bar, gaps: gaps, algorithm: .dwindle)
            t.expectEqual(frames2.count, 2, "2 windows produce 2 frames")
            if let f1 = frames2[1], let f2 = frames2[2] {
                let inter = f1.intersection(f2)
                t.expect(inter.isNull || inter.width <= 0 || inter.height <= 0, "w1 and w2 do not overlap")
                let seam = f2.minX - f1.maxX
                t.expect(abs(seam - gaps.inner) <= 1.0, "seam between w1 and w2 equals gaps.inner (8)")
                t.expectEqual(f1.minY, f2.minY, "w1 and w2 have same top")
                t.expectEqual(f1.height, f2.height, "w1 and w2 have same height")
            } else {
                t.fail("missing windows 1 or 2")
            }

            // 3. 5 windows dwindle: no overlaps, all inside usable
            let ids5: [WindowID] = [10, 20, 30, 40, 50]
            let frames5 = LayoutEngine.layout(ids: ids5, screen: screen, bar: bar, gaps: gaps, algorithm: .dwindle)
            t.expectEqual(frames5.count, 5, "5 windows produce 5 frames")
            let usableY: CGFloat = 6 + 38 + 8
            let rects = ids5.compactMap { frames5[$0] }
            for (i, r1) in rects.enumerated() {
                t.expect(r1.minY >= usableY, "window \(i) minY >= bar inset")
                t.expect(r1.maxX <= screen.maxX - 8, "window \(i) inside screen width")
                t.expect(r1.maxY <= screen.maxY - 8, "window \(i) inside screen height")

                for (j, r2) in rects.enumerated() where i < j {
                    let inter = r1.intersection(r2)
                    t.expect(inter.isNull || inter.width <= 0 || inter.height <= 0, "window \(i) and \(j) do not overlap")
                }
            }

            // 4. Bar inset reservation across 1...12 windows on 1512x982 and 2560x1440 with non-zero origin
            let testScreens: [CGRect] = [
                CGRect(x: 0, y: 0, width: 1512, height: 982),
                CGRect(x: 1512, y: -200, width: 2560, height: 1440)
            ]
            let customBar = BarInset(marginTop: 10, height: 38)
            let customGaps = Gaps(outer: 12, inner: 8)

            for s in testScreens {
                let expectedMinY = s.minY + customBar.marginTop + customBar.height + customGaps.outer
                for count in 1...12 {
                    let ids = (1...count).map { WindowID($0) }
                    let frames = LayoutEngine.layout(ids: ids, screen: s, bar: customBar, gaps: customGaps, algorithm: .dwindle)
                    t.expectEqual(frames.count, count, "screen \(Int(s.width))x\(Int(s.height)) count=\(count)")
                    for (wid, frame) in frames {
                        t.expect(frame.minY >= expectedMinY, "count=\(count) wid=\(wid) minY (\(frame.minY)) >= bar inset (\(expectedMinY))")
                        t.expect(frame.minX >= s.minX + customGaps.outer, "count=\(count) wid=\(wid) minX >= outer gap")
                        t.expect(frame.maxX <= s.maxX - customGaps.outer, "count=\(count) wid=\(wid) maxX <= outer gap")
                        t.expect(frame.maxY <= s.maxY - customGaps.outer, "count=\(count) wid=\(wid) maxY <= outer gap")
                    }
                }
            }

            // 5. Master-stack algorithm & ratio clamping
            let framesMS = LayoutEngine.layout(
                ids: [1, 2, 3],
                screen: screen,
                bar: bar,
                gaps: gaps,
                algorithm: .masterStack,
                splitRatio: 0.55
            )
            t.expectEqual(framesMS.count, 3, "master-stack 3 windows")
            if let master = framesMS[1], let s1 = framesMS[2], let s2 = framesMS[3] {
                t.expect(master.width > s1.width, "master width is > stack width")
                t.expect(abs(s1.minX - master.maxX - 8) <= 1.0, "master and stack are side-by-side with inner gap")
                t.expect(s1.maxY + 8 <= s2.minY + 1.0, "stack window 1 above stack window 2")
                t.expectEqual(s1.width, s2.width, "stack windows have same width")
            } else {
                t.fail("missing master-stack frames")
            }

            // Ratio clamping extremes (0.01 and 0.99 should clamp safely)
            let clampedLow = LayoutEngine.layout(ids: [1, 2], screen: screen, bar: bar, gaps: gaps, splitRatio: 0.01)
            let clampedHigh = LayoutEngine.layout(ids: [1, 2], screen: screen, bar: bar, gaps: gaps, splitRatio: 0.99)
            t.expect((clampedLow[1]?.width ?? 0) >= LayoutEngine.minWidth, "low ratio clamped above minWidth")
            t.expect((clampedHigh[2]?.width ?? 0) >= LayoutEngine.minWidth, "high ratio leaves second window above minWidth")

            // 6. Min-size guard
            let smallScreen = CGRect(x: 0, y: 0, width: 150, height: 80)
            let zeroBar = BarInset(marginTop: 0, height: 0)
            let tightGaps = Gaps(outer: 0, inner: 4)
            let framesSmall = LayoutEngine.layout(ids: [1, 2, 3], screen: smallScreen, bar: zeroBar, gaps: tightGaps)
            t.expectEqual(framesSmall.count, 3, "small screen produces frames without crash")
            for (_, f) in framesSmall {
                t.expect(f.width > 0, "frame size positive width")
                t.expect(f.height > 0, "frame size positive height")
            }

            // 7. BorderGeometry math & Coordinate Flipping
            let winAX = CGRect(x: 100, y: 200, width: 400, height: 300)
            let ring = BorderGeometry.ringRect(windowFrameAX: winAX, borderWidth: 4)
            t.expectEqual(ring.minX, 98, "ring rect insetBy -2 on left")
            t.expectEqual(ring.minY, 198, "ring rect insetBy -2 on top")
            t.expectEqual(ring.width, 404, "ring rect width +4")
            t.expectEqual(ring.height, 304, "ring rect height +4")

            let ringAppKit = BorderGeometry.ringRectAppKit(
                windowFrameAX: winAX,
                borderWidth: 4,
                primaryScreenHeight: 982
            )
            // Expected AppKit y = 982 - (198 + 304) = 480
            t.expectEqual(ringAppKit, CGRect(x: 98, y: 480, width: 404, height: 304), "ringRectAppKit flips Quartz top-left to AppKit bottom-left")

            let clamped = BorderGeometry.clampedWidth(width: 12, innerGap: 8)
            t.expectEqual(clamped, 8, "border width clamped to inner gap (8)")
            let minClamp = BorderGeometry.clampedWidth(width: 0.5, innerGap: 8)
            t.expectEqual(minClamp, 1.0, "border width min clamped to 1.0")

            // 8. MainActor tests for BorderOverlayWindow, TilingController, and BorderController with MockAXWindowProvider
            MainActor.assumeIsolated {
                runControllerTests(t)
            }
        }
    }

    @MainActor
    private static func runControllerTests(_ t: Harness) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let screenModel = ScreenModel(
            id: 9501,
            uuid: "test-layout-screen",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            safeTop: 38,
            isPrimary: true
        )

        // BorderOverlayWindow safety invariants (Guardrail 4)
        let borderWin = BorderOverlayWindow(screen: screenModel)
        t.expect(borderWin.ignoresMouseEvents, "borderWin: ignoresMouseEvents == true")
        borderWin.ignoresMouseEvents = false
        t.expect(borderWin.ignoresMouseEvents, "borderWin: ignoresMouseEvents locked to true")
        t.expect(!borderWin.isOpaque, "borderWin: isOpaque == false")
        t.expect(borderWin.backgroundColor.alphaComponent == 0, "borderWin: backgroundColor == .clear")
        t.expect(!borderWin.hasShadow, "borderWin: hasShadow == false")
        t.expect(!borderWin.canBecomeKey, "borderWin: canBecomeKey == false")
        t.expect(!borderWin.canBecomeMain, "borderWin: canBecomeMain == false")
        borderWin.close()

        // Synthetic window set testing self-exclusion, layer!=0, minimized, hidden, and tiny popups
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let validWin1 = ManagedWindow(
            id: 501,
            pid: 1234,
            bundleId: "com.apple.Terminal",
            title: "zsh",
            frame: CGRect(x: 50, y: 80, width: 600, height: 400),
            layer: 0
        )
        let validWin2 = ManagedWindow(
            id: 502,
            pid: 1235,
            bundleId: "com.apple.Safari",
            title: "Start Page",
            frame: CGRect(x: 700, y: 80, width: 600, height: 400),
            layer: 0
        )
        let selfPIDWin = ManagedWindow(
            id: 503,
            pid: ownPID,
            bundleId: "dev.persona.mode",
            title: "Persona TopBar",
            frame: CGRect(x: 10, y: 6, width: 1492, height: 38),
            layer: 25
        )
        let nonZeroLayerWin = ManagedWindow(
            id: 504,
            pid: 1236,
            bundleId: "com.example.overlay",
            title: "Overlay",
            frame: CGRect(x: 100, y: 100, width: 500, height: 400),
            layer: 3
        )
        let minimizedWin = ManagedWindow(
            id: 505,
            pid: 1237,
            bundleId: "com.apple.Notes",
            title: "Minimized Note",
            frame: CGRect(x: 100, y: 100, width: 500, height: 400),
            layer: 0,
            isMinimized: true
        )
        let hiddenWin = ManagedWindow(
            id: 506,
            pid: 1238,
            bundleId: "com.apple.Mail",
            title: "Hidden Mail",
            frame: CGRect(x: 100, y: 100, width: 500, height: 400),
            layer: 0,
            isHidden: true
        )
        let tinyPopupWin = ManagedWindow(
            id: 507,
            pid: 1239,
            bundleId: "com.example.tooltip",
            title: "Tooltip",
            frame: CGRect(x: 200, y: 200, width: 80, height: 30),
            layer: 0
        )

        let mockProvider = MockAXWindowProvider(
            windows: [validWin1, validWin2, selfPIDWin, nonZeroLayerWin, minimizedWin, hiddenWin, tinyPopupWin],
            focusedID: 501
        )

        let cfg = AppConfig()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("persona-layout-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let journal = FrameJournal(supportDir: tempDir)

        // Test 1: Graceful AX fallback when untrusted -> no-op, 0 setFrameCalls
        let untrustedController = TilingController(
            provider: mockProvider,
            config: cfg,
            journal: journal,
            isAXTrusted: { false },
            screenProvider: { [screenModel] }
        )
        untrustedController.retile(screen: screenModel)
        t.expectEqual(mockProvider.setFrameCalls.count, 0, "untrusted AX fallback makes 0 setFrameCalls")

        // Test 2: Trusted AX tiling -> tiles only validWin1 and validWin2, reserves 38pt Top Bar + marginTop + outerGap
        let trustedController = TilingController(
            provider: mockProvider,
            config: cfg,
            journal: journal,
            isAXTrusted: { true },
            screenProvider: { [screenModel] }
        )
        trustedController.retile(screen: screenModel)
        t.expectEqual(mockProvider.setFrameCalls.count, 2, "only the 2 valid normal-layer windows are tiled")
        let tiledIDs = Set(mockProvider.setFrameCalls.map(\.id))
        t.expectEqual(tiledIDs, Set([501, 502]), "self-PID, non-zero layer, minimized, hidden, and tiny popups excluded")

        let expectedMinTop = cfg.topBar.marginTop + 38 + cfg.tiling.gaps.outer
        for call in mockProvider.setFrameCalls {
            t.expect(call.frame.minY >= expectedMinTop, "tiled window \(call.id) reserves 38pt top bar + outer gap (minY=\(call.frame.minY) >= \(expectedMinTop))")
        }

        // Test 3: FrameJournal recorded pre-tile frames and restores them cleanly
        t.expect(journal.hasEntry(for: 501), "journal recorded original frame for 501")
        t.expect(journal.hasEntry(for: 502), "journal recorded original frame for 502")
        t.expect(!journal.hasEntry(for: 503), "journal did not record self window 503")
        mockProvider.setFrameCalls.removeAll()
        trustedController.restoreFrames()
        t.expectEqual(mockProvider.setFrameCalls.count, 2, "restoreFrames restores both tiled windows")
        if let restored1 = mockProvider.windows.first(where: { $0.id == 501 })?.frame {
            t.expectEqual(restored1, CGRect(x: 50, y: 80, width: 600, height: 400), "window 501 restored to original frame")
        }

        // Test 4: BorderController tracking & self/invalid window filtering
        let borderController = BorderController(
            provider: mockProvider,
            config: cfg,
            screenProvider: { [screenModel] }
        )
        borderController.start(orderFront: false)
        t.expect(borderController.isBorderVisible, "border visible on valid focused window 501")
        t.expectEqual(borderController.currentFocusedID, 501, "focused ID is 501")
        if let appKitRing = borderController.currentBorderFrameAppKit {
            let expectedRing = BorderGeometry.ringRectAppKit(
                windowFrameAX: CGRect(x: 50, y: 80, width: 600, height: 400),
                borderWidth: cfg.border.width,
                primaryScreenHeight: 982
            )
            t.expectEqual(appKitRing, expectedRing, "border controller converts AX window frame to AppKit ring frame")
        }

        // Focus self window -> border hides
        mockProvider.focusedID = 503
        borderController.updateFocus()
        t.expect(!borderController.isBorderVisible, "border hides when focused window is Persona Mode own PID")

        // Focus non-zero layer window -> border hides
        mockProvider.focusedID = 504
        borderController.updateFocus()
        t.expect(!borderController.isBorderVisible, "border hides when focused window has layer != 0")

        // Focus minimized window -> border hides
        mockProvider.focusedID = 505
        borderController.updateFocus()
        t.expect(!borderController.isBorderVisible, "border hides when focused window is minimized")

        // Focus tiny popup -> border hides
        mockProvider.focusedID = 507
        borderController.updateFocus()
        t.expect(!borderController.isBorderVisible, "border hides when focused window is tiny popup (<100x50)")

        borderController.stop()
        t.expectEqual(borderController.borderWindows.count, 0, "borderController closes all windows on stop")

        // Test 5: SystemAXWindowProvider window-move gate with PERSONA_NO_WINDOW_MOVES=1
        let gatedSystemProvider = SystemAXWindowProvider(
            environmentProvider: { ["PERSONA_NO_WINDOW_MOVES": "1"] }
        )
        let gatedResult = gatedSystemProvider.setWindowFrame(
            window: validWin1,
            frame: CGRect(x: 100, y: 100, width: 500, height: 400)
        )
        t.expect(gatedResult, "SystemAXWindowProvider.setWindowFrame returns true without calling AX when PERSONA_NO_WINDOW_MOVES=1")
    }
}
