import AppKit
import Foundation
import PersonaCore

/// Available user and system commands in Persona Mode.
public enum PersonaCommand: Equatable {
    case tileNow
    case toggleFloatFocused
    case reloadTheme
    case toggleDarkHour
    case openTerminal
    case showLauncher
    case hideLauncher
    case toggleLauncher
    case switchSpace(Int)
    case exitPersona
    case panic

    public static func from(string: String) -> PersonaCommand? {
        switch string.lowercased().trimmingCharacters(in: .whitespaces) {
        case "tile", "tilenow":
            return .tileNow
        case "togglefloat", "float":
            return .toggleFloatFocused
        case "reload", "reloadtheme":
            return .reloadTheme
        case "toggledarkhour", "darkhour":
            return .toggleDarkHour
        case "terminal", "openterminal":
            return .openTerminal
        case "launcher", "showlauncher":
            return .showLauncher
        case "hidelauncher":
            return .hideLauncher
        case "togglelauncher":
            return .toggleLauncher
        case "exit", "quit", "exitpersona":
            return .exitPersona
        case "panic":
            return .panic
        default:
            if string.starts(with: "space:") {
                let numStr = string.dropFirst(6)
                if let n = Int(numStr) {
                    return .switchSpace(n)
                }
            }
            return nil
        }
    }
}

/// Central command dispatch for user and IPC actions.
@MainActor
public final class CommandRouter {
    public static let shared = CommandRouter()

    public var onTile: (() -> Void)?
    public var onToggleFloat: (() -> Void)?
    public var onReloadTheme: (() -> Void)?
    public var onToggleDarkHour: (() -> Void)?
    public var onOpenTerminal: (() -> Void)?
    public var onShowLauncher: (() -> Void)?
    public var onHideLauncher: (() -> Void)?
    public var onToggleLauncher: (() -> Void)?
    public var onSwitchSpace: ((Int) -> Void)?
    public var onExitPersona: (() -> Void)?
    public var onPanic: (() -> Void)?

    public init() {}

    public func send(_ command: PersonaCommand) {
        switch command {
        case .tileNow:
            onTile?()
        case .toggleFloatFocused:
            onToggleFloat?()
        case .reloadTheme:
            onReloadTheme?()
        case .toggleDarkHour:
            if let custom = onToggleDarkHour {
                custom()
            } else {
                AppState.shared.toggleDarkHour()
            }
        case .openTerminal:
            onOpenTerminal?()
        case .showLauncher:
            onShowLauncher?()
        case .hideLauncher:
            onHideLauncher?()
        case .toggleLauncher:
            onToggleLauncher?()
        case .switchSpace(let n):
            onSwitchSpace?(n)
        case .exitPersona:
            if let custom = onExitPersona {
                custom()
            } else {
                NotificationCenter.default.post(
                    name: NSNotification.Name("dev.persona.mode.exit"),
                    object: nil
                )
            }
        case .panic:
            if let custom = onPanic {
                custom()
            } else {
                _ = RestoreService.shared?.restoreAll(reason: .panic)
                exit(0)
            }
        }
    }
}
