import CoreGraphics
import Foundation
import PersonaCore

enum CoordSuite {
    static func run(_ t: Harness) {
        t.suite("coords") {
            // --- Known values: single 1512x982 display (primary) ---
            let H: CGFloat = 982
            let topStrip = CGRect(x: 0, y: 940, width: 1512, height: 42) // AppKit: top 42pt
            t.expectEqual(CoordinateSpace.toAX(topStrip, primaryHeight: H), CGRect(x: 0, y: 0, width: 1512, height: 42), "top strip maps to AX y=0")
            let bottomStrip = CGRect(x: 0, y: 0, width: 1512, height: 30)
            t.expectEqual(CoordinateSpace.toAX(bottomStrip, primaryHeight: H), CGRect(x: 0, y: 952, width: 1512, height: 30), "bottom strip maps to AX y=952")
            t.expectEqual(CoordinateSpace.toAppKit(CGRect(x: 100, y: 200, width: 300, height: 400), primaryHeight: H),
                          CGRect(x: 100, y: 382, width: 300, height: 400), "toAppKit known value")

            // --- Round trip, incl. negative-origin / stacked secondary displays ---
            let rects: [CGRect] = [
                CGRect(x: 0, y: 0, width: 1512, height: 982),
                CGRect(x: -1920, y: -100, width: 1920, height: 1080),      // left of primary, offset down
                CGRect(x: 0, y: 982, width: 2560, height: 1440),           // stacked above primary
                CGRect(x: -300, y: -2000, width: 123.5, height: 77.25),   // below + fractional
            ]
            for r in rects {
                let ax = CoordinateSpace.toAX(r, primaryHeight: H)
                t.expectEqual(CoordinateSpace.toAppKit(ax, primaryHeight: H), r, "round trip \(r)")
                t.expectEqual(ax.size, r.size, "size preserved \(r)")
            }
            // A display stacked above primary has negative AX y.
            let above = CoordinateSpace.toAX(CGRect(x: 0, y: 982, width: 2560, height: 1440), primaryHeight: H)
            t.expectEqual(above.origin.y, -1440, "display above primary has negative AX y")
            t.expectEqual(CoordinateSpace.flip(CGPoint(x: 5, y: 10), primaryHeight: H), CGPoint(x: 5, y: 972), "flip point")

            // --- Bar frame math (non-notched) ---
            let cfg = TopBarConfig()
            let plain = CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let bar = WindowGeometry.barFrame(screenFrame: plain, safeTop: 0, config: cfg)
            t.expectEqual(bar, CGRect(x: 10, y: 1040, width: 1900, height: 34), "bar frame on plain 1080p display")
            t.expect(bar.maxY == plain.maxY - cfg.marginTop, "bar top sits marginTop below screen top")

            // --- Bar frame on a secondary display with negative origin ---
            let secondary = CGRect(x: -1920, y: -100, width: 1920, height: 1080)
            let secBar = WindowGeometry.barFrame(screenFrame: secondary, safeTop: 0, config: cfg)
            t.expectEqual(secBar.minX, -1910, "secondary bar x honors negative origin + margin")
            t.expectEqual(secBar.maxY, 974, "secondary bar y relative to its own top edge")
            t.expect(secondary.insetBy(dx: 0, dy: 0).contains(secBar), "secondary bar inside its screen")

            // --- Notch: bar grows to at least the safe-area inset ---
            let mbp = CGRect(x: 0, y: 0, width: 1512, height: 982)
            t.expectEqual(WindowGeometry.barHeight(configHeight: 34, safeTop: 32), 34, "config height wins when taller than notch")
            t.expectEqual(WindowGeometry.barHeight(configHeight: 34, safeTop: 38), 38, "notch inset wins when taller than config")
            let notchBar = WindowGeometry.barFrame(screenFrame: mbp, safeTop: 38, config: cfg)
            t.expectEqual(notchBar.height, 38, "notch bar height")
            t.expectEqual(notchBar.minY, 982 - 6 - 38, "notch bar y")

            // --- Cluster split around the notch ---
            let auxLeft = CGRect(x: 0, y: 944, width: 650, height: 38)
            let auxRight = CGRect(x: 862, y: 944, width: 650, height: 38)
            let split = WindowGeometry.clusterSplit(barFrame: notchBar, auxLeft: auxLeft, auxRight: auxRight)
            t.expectEqual(split?.leftWidth, 640, "left cluster ends at notch")
            t.expectEqual(split?.rightWidth, 640, "right cluster starts after notch")
            t.expectEqual(split?.gap, 212, "notch gap width")
            t.expect(WindowGeometry.clusterSplit(barFrame: bar, auxLeft: nil, auxRight: nil) == nil, "no split without notch")
            t.expect(WindowGeometry.clusterSplit(barFrame: bar, auxLeft: auxLeft, auxRight: nil) == nil, "no split with one aux area")

            // --- Overlay + reserved edge ---
            t.expectEqual(WindowGeometry.overlayFrame(screenFrame: secondary), secondary, "overlay covers the full screen frame")
            t.expectEqual(WindowGeometry.reservedTopEdge(barFrame: bar), 1040, "reserved edge is the bar's bottom")

            // --- Width never negative on absurd configs ---
            var tiny = TopBarConfig()
            tiny.marginSide = 500
            t.expect(WindowGeometry.barFrame(screenFrame: CGRect(x: 0, y: 0, width: 400, height: 300), safeTop: 0, config: tiny).width >= 0, "bar width clamped >= 0")
        }
    }
}
