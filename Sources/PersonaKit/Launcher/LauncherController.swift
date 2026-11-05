import AppKit
import Foundation
import PersonaCore

/// Manages the lifecycle, keyboard navigation, and execution of the Floating P3R App Launcher.
@MainActor
public final class LauncherController {
    public static let shared = LauncherController()

    public let viewModel = LauncherViewModel()
    public private(set) var panel: LauncherPanel?
    public var onCustomExecute: ((LauncherItem, Bool) -> Void)?

    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?

    public init() {
        viewModel.onActivateItem = { [weak self] item, reveal in
            self?.execute(item: item, revealInFinder: reveal)
        }
        viewModel.onCancel = { [weak self] in
            self?.hide()
        }
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    public func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    public func show() {
        let targetScreen = screenUnderMouse()
        let launcherPanel: LauncherPanel
        if let existing = panel {
            existing.reposition(for: targetScreen)
            launcherPanel = existing
        } else {
            let hostView = FirstMouseHostingView(rootView: LauncherView(viewModel: viewModel))
            let created = LauncherPanel(screen: targetScreen, content: hostView)
            self.panel = created
            launcherPanel = created
        }

        // Reset query and refresh matches on every show
        viewModel.updateQuery("")

        installEventMonitors(for: launcherPanel)

        NSApp.activate(ignoringOtherApps: true)
        launcherPanel.alphaValue = 1.0
        launcherPanel.makeKeyAndOrderFront(nil)
        launcherPanel.orderFrontRegardless()
    }

    public func hide() {
        removeEventMonitors()
        panel?.orderOut(nil)
    }

    public func stop() {
        hide()
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }

    /// Simulates or handles a focus-loss (resign key) event, dismissing the launcher cleanly.
    public func handleFocusLoss() {
        hide()
    }

    /// Processes a keyboard event while the launcher is active.
    /// Exposed for deterministic state-machine testing in `persona-selftest` and `--probe launcher-open`.
    @discardableResult
    public func handleKeyCode(
        _ keyCode: UInt16,
        characters: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> Bool {
        let hasCmd = modifiers.contains(.command)
        let hasCtrl = modifiers.contains(.control)
        let lower = characters.lowercased()

        // Esc -> dismiss
        if keyCode == 53 {
            hide()
            return true
        }

        // Cmd+Q -> confirmation-free Exit Persona Mode
        if hasCmd && (keyCode == 12 || lower == "q") {
            hide()
            CommandRouter.shared.send(.exitPersona)
            return true
        }

        // Up arrow (126) or Ctrl+K / Ctrl+P
        if keyCode == 126 || (hasCtrl && (lower == "k" || lower == "p")) {
            viewModel.moveSelectionUp()
            return true
        }

        // Down arrow (125) or Ctrl+J / Ctrl+N
        if keyCode == 125 || (hasCtrl && (lower == "j" || lower == "n")) {
            viewModel.moveSelectionDown()
            return true
        }

        // Return (36) or Keypad Enter (76)
        if keyCode == 36 || keyCode == 76 {
            viewModel.activateSelected(revealInFinder: hasCmd)
            return true
        }

        // Cmd+1 ... Cmd+9 quick pick
        if hasCmd, let digit = Int(lower), digit >= 1 && digit <= 9 {
            viewModel.activate(at: digit - 1, revealInFinder: false)
            return true
        }

        // Delete / Backspace (51)
        if keyCode == 51 {
            if hasCmd {
                viewModel.updateQuery("")
            } else if !viewModel.query.isEmpty {
                viewModel.updateQuery(String(viewModel.query.dropLast()))
            }
            return true
        }

        // Printable text input
        if !hasCmd && !hasCtrl, !characters.isEmpty {
            let filtered = characters.filter { !$0.isNewline && ($0 == " " || !$0.isWhitespace) }
            if !filtered.isEmpty {
                viewModel.updateQuery(viewModel.query + filtered)
                return true
            }
        }

        return false
    }

    public func execute(item: LauncherItem, revealInFinder: Bool = false) {
        hide()

        if let custom = onCustomExecute {
            custom(item, revealInFinder)
            return
        }

        switch item {
        case .action(let entry):
            CommandRouter.shared.send(entry.command)

        case .app(let entry):
            if revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([entry.url])
            } else {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: entry.url, configuration: config, completionHandler: nil)
            }
        }
    }

    public func executeByIdentifier(_ identifier: String) -> Bool {
        let allResults = AppIndexer.shared.search(query: "")
        for entry in allResults {
            switch entry.item {
            case .action(let act):
                if entry.item.id == identifier || "action:\(act.id)" == identifier || act.id == identifier {
                    execute(item: entry.item)
                    return true
                }
            case .app(let app):
                if entry.item.id == identifier || "app:\(app.bundleId)" == identifier || app.bundleId.lowercased() == identifier.ReplacingPrefix("app:").lowercased() {
                    execute(item: entry.item)
                    return true
                }
            }
        }
        return false
    }

    private func screenUnderMouse() -> ScreenModel {
        let mouse = NSEvent.mouseLocation
        let screens = ScreenModel.current()
        if let match = screens.first(where: { $0.frame.contains(mouse) }) {
            return match
        }
        return screens.first ?? ScreenModel(
            id: 1,
            uuid: "fallback",
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            isPrimary: true
        )
    }

    private func installEventMonitors(for panel: LauncherPanel) {
        removeEventMonitors()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            let chars = event.charactersIgnoringModifiers ?? ""
            let handled = self.handleKeyCode(
                event.keyCode,
                characters: chars,
                modifiers: event.modifierFlags
            )
            return handled ? nil : event
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.hide()
            }
        }
    }

    private func removeEventMonitors() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
    }
}

private extension String {
    func ReplacingPrefix(_ prefix: String) -> String {
        if self.hasPrefix(prefix) {
            return String(self.dropFirst(prefix.count))
        }
        return self
    }
}

