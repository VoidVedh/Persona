import AppKit
import Foundation
import PersonaCore

public typealias StatusItemController = StatusBarController

/// Manages the native macOS Menu Bar status item (`NSStatusItem`) for Persona Mode.
@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    public static let shared = StatusBarController()

    public private(set) var statusItem: NSStatusItem?
    public private(set) var menu: NSMenu?

    public var isInstalled: Bool {
        statusItem != nil
    }

    public override init() {
        super.init()
    }

    public func start() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = Self.makeCrescentTemplateImage()
            button.toolTip = "Persona Mode — Dark Hour Desktop Environment"
            button.setAccessibilityIdentifier("statusbar.persona")
        }

        let statusMenu = buildMenu()
        statusMenu.delegate = self
        item.menu = statusMenu

        self.statusItem = item
        self.menu = statusMenu
    }

    public func stop() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        menu = nil
    }

    public func buildMenu() -> NSMenu {
        let m = NSMenu(title: "Persona Mode")
        m.autoenablesItems = false
        populateMenu(m)
        return m
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        populateMenu(menu)
    }

    private func populateMenu(_ m: NSMenu) {
        let modeLabel = AppState.shared.runMode == .dryRun ? "DRY RUN" : "LIVE"
        let header = NSMenuItem(title: "Persona Mode — \(modeLabel)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        m.addItem(header)

        m.addItem(.separator())

        let launcherItem = NSMenuItem(
            title: "Open P3R Launcher",
            action: #selector(handleOpenLauncher),
            keyEquivalent: " "
        )
        launcherItem.keyEquivalentModifierMask = [.option]
        launcherItem.target = self
        m.addItem(launcherItem)

        let tileItem = NSMenuItem(
            title: "Retile Windows Now",
            action: #selector(handleTileNow),
            keyEquivalent: "t"
        )
        tileItem.keyEquivalentModifierMask = [.control, .option]
        tileItem.target = self
        m.addItem(tileItem)

        let floatItem = NSMenuItem(
            title: "Toggle Active Window Float",
            action: #selector(handleToggleFloat),
            keyEquivalent: "f"
        )
        floatItem.keyEquivalentModifierMask = [.control, .option]
        floatItem.target = self
        m.addItem(floatItem)

        let toggleTilingItem = NSMenuItem(
            title: TilingController.shared.isEnabled ? "Toggle Tiling (Currently On)" : "Toggle Tiling (Currently Off)",
            action: #selector(handleToggleTiling),
            keyEquivalent: ""
        )
        toggleTilingItem.target = self
        m.addItem(toggleTilingItem)

        let toggleBorderItem = NSMenuItem(
            title: BorderController.shared.isEnabled ? "Toggle Active Border (Currently On)" : "Toggle Active Border (Currently Off)",
            action: #selector(handleToggleBorder),
            keyEquivalent: ""
        )
        toggleBorderItem.target = self
        m.addItem(toggleBorderItem)

        let isDarkHour = AppState.shared.darkHourPhase == .darkHour
        let darkHourItem = NSMenuItem(
            title: isDarkHour ? "Toggle Dark Hour / Daytime Theme (Dark Hour)" : "Toggle Dark Hour / Daytime Theme (Daytime)",
            action: #selector(handleToggleDarkHour),
            keyEquivalent: ""
        )
        darkHourItem.target = self
        m.addItem(darkHourItem)

        let reloadItem = NSMenuItem(
            title: "Reload Theme",
            action: #selector(handleReloadTheme),
            keyEquivalent: "r"
        )
        reloadItem.keyEquivalentModifierMask = [.control, .option]
        reloadItem.target = self
        m.addItem(reloadItem)

        let terminalItem = NSMenuItem(
            title: "Open Terminal (P3R)",
            action: #selector(handleOpenTerminal),
            keyEquivalent: "\r"
        )
        terminalItem.keyEquivalentModifierMask = [.control, .option]
        terminalItem.target = self
        m.addItem(terminalItem)

        m.addItem(.separator())

        let trusted = AXPermission.shared.isTrusted
        if trusted {
            let axItem = NSMenuItem(title: "Accessibility: Granted", action: nil, keyEquivalent: "")
            axItem.isEnabled = false
            m.addItem(axItem)
        } else {
            let axItem = NSMenuItem(
                title: "Accessibility: Not Granted — Open Settings…",
                action: #selector(handleOpenAXSettings),
                keyEquivalent: ""
            )
            axItem.target = self
            m.addItem(axItem)
        }

        for hkErr in AppState.shared.hotkeyErrors {
            let errItem = NSMenuItem(title: "Hotkey Warning: \(hkErr)", action: nil, keyEquivalent: "")
            errItem.isEnabled = false
            m.addItem(errItem)
        }

        for cfgWarn in AppState.shared.configWarnings {
            let warnItem = NSMenuItem(title: "Config Warning: \(cfgWarn)", action: nil, keyEquivalent: "")
            warnItem.isEnabled = false
            m.addItem(warnItem)
        }

        m.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Return to macOS (Quit)",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        m.addItem(quitItem)
    }

    @objc public func handleOpenLauncher() {
        CommandRouter.shared.send(.showLauncher)
    }

    @objc public func handleTileNow() {
        CommandRouter.shared.send(.tileNow)
    }

    @objc public func handleToggleFloat() {
        CommandRouter.shared.send(.toggleFloatFocused)
    }

    @objc public func handleToggleTiling() {
        TilingController.shared.setEnabled(!TilingController.shared.isEnabled)
    }

    @objc public func handleToggleBorder() {
        BorderController.shared.isEnabled.toggle()
        if BorderController.shared.isEnabled {
            BorderController.shared.updateFocus()
        } else {
            BorderController.shared.clearBorder()
        }
    }

    @objc public func handleToggleDarkHour() {
        CommandRouter.shared.send(.toggleDarkHour)
    }

    @objc public func handleReloadTheme() {
        CommandRouter.shared.send(.reloadTheme)
    }

    @objc public func handleOpenTerminal() {
        CommandRouter.shared.send(.openTerminal)
    }

    @objc public func handleOpenAXSettings() {
        AXPermission.shared.openSettings()
    }

    @objc public func handleQuit() {
        CommandRouter.shared.send(.exitPersona)
    }

    /// Procedurally draws a 16x16 crescent moon template icon for the macOS menu bar.
    public static func makeCrescentTemplateImage() -> NSImage {
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            let outer = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 12, height: 12))
            let inner = NSBezierPath(ovalIn: NSRect(x: 5.5, y: 3.5, width: 10, height: 10))
            let path = NSBezierPath()
            path.append(outer)
            path.append(inner.reversed)
            path.windingRule = .nonZero
            path.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

