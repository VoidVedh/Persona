import AppKit
import Foundation
import PersonaCore
import PersonaKit

/// Asserts the real NSWindow configuration mandated for the Phase 2 window host layer.
/// Windows are created but never ordered front, so the run is invisible to the user.
enum WindowSuite {
    static func run(_ t: Harness) {
        t.suite("windows") {
            MainActor.assumeIsolated { body(t) }
        }
    }

    @MainActor
    private static func screen(id: CGDirectDisplayID, frame: CGRect, safeTop: CGFloat = 0, primary: Bool = false) -> ScreenModel {
        ScreenModel(id: id, uuid: "test-\(id)", frame: frame, safeTop: safeTop, isPrimary: primary)
    }

    @MainActor
    private static func body(_ t: Harness) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let primary = screen(id: 9001, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), primary: true)
        let cfg = AppConfig()

        // ---------------- Top bar panel ----------------
        let bar = TopBarPanel(screen: primary, config: cfg.topBar, content: NSView())
        t.expect(bar.styleMask.contains(.borderless), "bar: styleMask has .borderless")
        t.expect(bar.styleMask.contains(.nonactivatingPanel), "bar: styleMask has .nonactivatingPanel")
        t.expect(!bar.styleMask.contains(.titled), "bar: not titled")
        t.expectEqual(bar.level, NSWindow.Level.statusBar, "bar: level == .statusBar")
        t.expectEqual(bar.level.rawValue, Int(CGWindowLevelForKey(.statusWindow)), "bar: level == CGWindowLevelForKey(.statusWindow)")
        t.expect(!bar.isOpaque, "bar: isOpaque == false")
        t.expect(bar.backgroundColor.alphaComponent == 0, "bar: backgroundColor is clear")
        t.expect(!bar.hasShadow, "bar: hasShadow == false")
        t.expect(!bar.hidesOnDeactivate, "bar: hidesOnDeactivate == false")
        t.expectEqual(bar.collectionBehavior, [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle], "bar: collectionBehavior exact")
        t.expect(!bar.canBecomeKey, "bar: canBecomeKey == false")
        t.expect(!bar.canBecomeMain, "bar: canBecomeMain == false")
        t.expect(!bar.ignoresMouseEvents, "bar: accepts clicks")
        t.expectEqual(bar.frame, CGRect(x: 10, y: 942, width: 1492, height: 34), "bar: frame on 1512x982")

        // Configured level is honored
        var alt = cfg.topBar
        alt.level = .mainMenuMinusOne
        t.expectEqual(WindowLevels.topBar(for: alt.level).rawValue, NSWindow.Level.mainMenu.rawValue - 1, "bar: mainMenuMinusOne level")

        // ---------------- Desktop overlay ----------------
        let overlay = DesktopOverlayWindow(screen: primary, mode: .overlay, content: nil)
        t.expect(overlay.ignoresMouseEvents, "overlay: ignoresMouseEvents == true at creation")
        overlay.ignoresMouseEvents = false
        t.expect(overlay.ignoresMouseEvents, "overlay: ignoresMouseEvents cannot be switched off")
        t.expectEqual(overlay.level.rawValue, Int(CGWindowLevelForKey(.desktopIconWindow)) - 1, "overlay: level == desktopIconWindow - 1")
        t.expectEqual(overlay.level, WindowLevels.desktopOverlay, "overlay: level == WindowLevels.desktopOverlay")
        t.expectEqual(overlay.collectionBehavior, [.canJoinAllSpaces, .stationary, .ignoresCycle], "overlay: collectionBehavior exact")
        t.expect(!overlay.canBecomeKey && !overlay.canBecomeMain, "overlay: never key/main")
        t.expect(!overlay.hasShadow, "overlay: hasShadow == false")
        t.expectEqual(overlay.sharingType, NSWindow.SharingType.none, "overlay: sharingType == .none")
        t.expectEqual(overlay.frame, primary.frame, "overlay: frame covers screen")
        t.expect(overlay.isOpaque, "overlay: opaque in wallpaper.mode=overlay")
        overlay.applyMode(.none)
        t.expect(!overlay.isOpaque && overlay.backgroundColor.alphaComponent == 0, "overlay: transparent in wallpaper.mode=none")
        t.expect(overlay.ignoresMouseEvents, "overlay: still click-through after mode change")

        // ---------------- Level ordering ----------------
        t.expect(overlay.level.rawValue < NSWindow.Level.normal.rawValue, "levels: overlay below normal windows")
        t.expect(overlay.level.rawValue < Int(CGWindowLevelForKey(.desktopIconWindow)), "levels: overlay below desktop icons")
        t.expect(bar.level.rawValue > NSWindow.Level.floating.rawValue, "levels: bar above floating windows")
        t.expect(WindowLevels.launcher.rawValue > bar.level.rawValue, "levels: launcher above bar")
        t.expect(WindowLevels.launcher.rawValue < NSWindow.Level.popUpMenu.rawValue, "levels: launcher below pop-up menus")

        // ---------------- Notch awareness ----------------
        let notched = ScreenModel(
            id: 9002, uuid: "notch", frame: CGRect(x: 0, y: 0, width: 1512, height: 982), safeTop: 38,
            auxLeft: CGRect(x: 0, y: 944, width: 650, height: 38),
            auxRight: CGRect(x: 862, y: 944, width: 650, height: 38), isPrimary: true
        )
        let notchBar = TopBarPanel(screen: notched, config: cfg.topBar, content: NSView())
        t.expectEqual(notchBar.frame.height, 38, "notch: bar height grows to safe inset")
        t.expectEqual(notchBar.clusterSplit?.gap, 212, "notch: cluster gap")
        t.expect(notched.hasNotch && !primary.hasNotch, "notch: hasNotch flags")

        // ---------------- WindowHostManager: create / reposition / remove ----------------
        var screens = [
            screen(id: 9101, frame: CGRect(x: 0, y: 0, width: 1512, height: 982), primary: true),
            screen(id: 9102, frame: CGRect(x: -1920, y: -100, width: 1920, height: 1080)),
        ]
        let manager = WindowHostManager(config: cfg, factory: PlaceholderContentFactory(), screenProvider: { screens })
        manager.start(orderFront: false)
        t.expectEqual(manager.entries.count, 2, "manager: one window pair per display")
        t.expect(manager.isRunning, "manager: running after start")
        let e1 = manager.entries[9101]
        let e2 = manager.entries[9102]
        t.expectEqual(e1?.bar.frame, CGRect(x: 10, y: 942, width: 1492, height: 34), "manager: primary bar frame")
        t.expectEqual(e2?.bar.frame.origin.x, -1910, "manager: secondary bar honors negative origin")
        t.expect(e1?.overlay.ignoresMouseEvents == true && e2?.overlay.ignoresMouseEvents == true, "manager: every overlay is click-through")

        // Resolution change on the primary -> windows are repositioned/resized in place.
        screens[0] = screen(id: 9101, frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), primary: true)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        t.expectEqual(manager.entries[9101]?.bar.frame, CGRect(x: 10, y: 1040, width: 1900, height: 34), "manager: bar resized after resolution change")
        t.expectEqual(manager.entries[9101]?.overlay.frame, CGRect(x: 0, y: 0, width: 1920, height: 1080), "manager: overlay resized after resolution change")
        t.expect(manager.entries[9101] === e1, "manager: window pair reused (not recreated) on resize")

        // Display unplugged -> its windows are closed; new display -> windows created.
        let removedBar = e2?.bar
        screens.removeLast()
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        t.expectEqual(manager.entries.count, 1, "manager: windows removed for unplugged display")
        t.expect(removedBar?.isVisible == false, "manager: removed bar is not visible")
        screens.append(screen(id: 9103, frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440)))
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        t.expectEqual(manager.entries.count, 2, "manager: windows created for hot-plugged display")
        t.expectEqual(manager.entries[9103]?.bar.frame, CGRect(x: 1930, y: 1400, width: 2540, height: 34), "manager: hot-plugged display bar frame")

        // Teardown: stop() closes everything and unsubscribes from notifications.
        manager.stop()
        t.expectEqual(manager.entries.count, 0, "manager: no windows after stop")
        t.expect(!manager.isRunning, "manager: not running after stop")
        screens.append(screen(id: 9104, frame: CGRect(x: 5000, y: 0, width: 800, height: 600)))
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        t.expectEqual(manager.entries.count, 0, "manager: ignores screen changes after stop (observers removed)")
        manager.stop() // idempotent
        t.expectEqual(manager.entries.count, 0, "manager: stop() is idempotent")

        // HUD only on primary when hud.primaryScreenOnly (overlay content swapped for an empty view)
        var hudCfg = AppConfig()
        hudCfg.hud.primaryScreenOnly = true
        let multi = [
            screen(id: 9201, frame: CGRect(x: 0, y: 0, width: 1000, height: 800), primary: true),
            screen(id: 9202, frame: CGRect(x: 1000, y: 0, width: 1000, height: 800)),
        ]
        let hudManager = WindowHostManager(config: hudCfg, factory: PlaceholderContentFactory(), screenProvider: { multi })
        hudManager.start(orderFront: false)
        t.expect(hudManager.entries[9201]?.overlay.contentView is FirstMouseHostingView<PlaceholderStripes>, "manager: primary overlay hosts HUD content")
        t.expect(!(hudManager.entries[9202]?.overlay.contentView is FirstMouseHostingView<PlaceholderStripes>), "manager: secondary overlay has no HUD content")
        hudManager.stop()
    }
}
