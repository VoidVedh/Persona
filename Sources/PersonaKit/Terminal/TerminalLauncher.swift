import AppKit
import Foundation
import PersonaCore

/// Detects installed terminals and launches an isolated Persona 3 Reload terminal session.
/// Never modifies `~/.config` or user shell dotfiles.
public final class TerminalLauncher {
    public static let shared = TerminalLauncher()

    public struct DetectionResult: Equatable {
        public let chosen: String
        public let available: [String]
        public let executableOrAppPath: String
        public let fastfetchAvailable: Bool

        public init(chosen: String, available: [String], executableOrAppPath: String, fastfetchAvailable: Bool) {
            self.chosen = chosen
            self.available = available
            self.executableOrAppPath = executableOrAppPath
            self.fastfetchAvailable = fastfetchAvailable
        }
    }

    public private(set) var lastLaunchCommand: [String] = []

    public init() {}

    /// Detects available terminals according to `preference` order.
    public func detect(preference: [String] = ["ghostty", "kitty", "wezterm", "alacritty", "terminal"]) -> DetectionResult {
        var available: [String] = []
        var paths: [String: String] = [:]

        let candidates: [(id: String, bundleId: String, binPaths: [String])] = [
            ("ghostty", "com.mitchellh.ghostty", ["/Applications/Ghostty.app", "/opt/homebrew/bin/ghostty", "/usr/local/bin/ghostty"]),
            ("kitty", "net.kovidgoyal.kitty", ["/Applications/kitty.app/Contents/MacOS/kitty", "/opt/homebrew/bin/kitty", "/usr/local/bin/kitty"]),
            ("wezterm", "com.github.wez.wezterm", ["/Applications/WezTerm.app/Contents/MacOS/wezterm", "/opt/homebrew/bin/wezterm", "/usr/local/bin/wezterm"]),
            ("alacritty", "org.alacritty", ["/Applications/Alacritty.app/Contents/MacOS/alacritty", "/opt/homebrew/bin/alacritty", "/usr/local/bin/alacritty"]),
            ("terminal", "com.apple.Terminal", ["/System/Applications/Utilities/Terminal.app"])
        ]

        let fm = FileManager.default
        for item in candidates {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleId) {
                available.append(item.id)
                paths[item.id] = appURL.path
                continue
            }
            if let foundPath = item.binPaths.first(where: { fm.fileExists(atPath: $0) }) {
                available.append(item.id)
                paths[item.id] = foundPath
            }
        }

        if !available.contains("terminal") {
            available.append("terminal")
            paths["terminal"] = "/System/Applications/Utilities/Terminal.app"
        }

        let chosen = preference.first(where: { available.contains($0.lowercased()) })?.lowercased() ?? "terminal"
        let chosenPath = paths[chosen] ?? "/System/Applications/Utilities/Terminal.app"
        let fastfetchFound = Self.isBinaryInstalled("fastfetch")

        return DetectionResult(
            chosen: chosen,
            available: available,
            executableOrAppPath: chosenPath,
            fastfetchAvailable: fastfetchFound
        )
    }

    public static func isBinaryInstalled(_ name: String) -> Bool {
        let searchPaths = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for path in searchPaths where FileManager.default.isExecutableFile(atPath: path) {
            return true
        }
        return false
    }

    /// Builds the isolated command arguments for launching the chosen terminal with the rendered profile directory.
    public func buildCommand(chosen: String, profileDir: URL) -> [String] {
        let runScript = profileDir.appendingPathComponent("run.command").path
        switch chosen {
        case "ghostty":
            let cfg = profileDir.appendingPathComponent("ghostty/config").path
            return [
                "/usr/bin/open", "-na", "Ghostty.app", "--args",
                "--config-default-files=false",
                "--config-file=\(cfg)",
                "-e", runScript
            ]
        case "kitty":
            let cfg = profileDir.appendingPathComponent("kitty/kitty.conf").path
            return [
                "/usr/bin/open", "-na", "kitty.app", "--args",
                "--config", cfg,
                runScript
            ]
        case "wezterm":
            let cfg = profileDir.appendingPathComponent("wezterm/wezterm.lua").path
            return [
                "/usr/bin/open", "-na", "WezTerm.app", "--args",
                "--config-file", cfg,
                "start", "--", runScript
            ]
        case "alacritty":
            let cfg = profileDir.appendingPathComponent("alacritty/alacritty.toml").path
            return [
                "/usr/bin/open", "-na", "Alacritty.app", "--args",
                "--config-file", cfg,
                "-e", runScript
            ]
        default:
            let termProfile = profileDir.appendingPathComponent("terminal-app/Persona3Reload.terminal").path
            return ["/usr/bin/open", termProfile]
        }
    }

    /// Opens an isolated Persona 3 Reload terminal session.
    @discardableResult
    public func launch(config: AppConfig = AppConfig(), mutator: SystemMutator? = nil) throws -> [String] {
        let profileDir: URL
        if let existing = ProfileRenderer.shared.renderedDirectory,
           FileManager.default.fileExists(atPath: existing.path) {
            profileDir = existing
        } else {
            profileDir = try ProfileRenderer.shared.render(mutator: mutator)
        }

        let detection = detect(preference: config.terminal.preference)
        let cmd = buildCommand(chosen: detection.chosen, profileDir: profileDir)
        lastLaunchCommand = cmd

        let env = ProcessInfo.processInfo.environment
        if env["PERSONA_DRY_RUN"] == "1" && env["PERSONA_LAUNCH_TERMINAL_LIVE"] != "1" {
            return cmd
        }

        if detection.chosen == "terminal" {
            // Write-ahead ledger entry for Terminal.app settings set before importing
            try mutator?.apply(.terminalProfile(name: TerminalAppProfile.profileName))

            let termProfileURL = profileDir.appendingPathComponent("terminal-app/Persona3Reload.terminal")
            let runScriptPath = profileDir.appendingPathComponent("run.command").path

            let openProc = Process()
            openProc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openProc.arguments = [termProfileURL.path]
            try? openProc.run()
            openProc.waitUntilExit()

            let script = """
            tell application "Terminal"
                activate
                do script "exec '\(runScriptPath)'" in front window
                set current settings of front window to settings set "\(TerminalAppProfile.profileName)"
            end tell
            """
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .milliseconds(350)) {
                var err: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    _ = appleScript.executeAndReturnError(&err)
                }
            }
        } else if let exe = cmd.first {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: exe)
            proc.arguments = Array(cmd.dropFirst())
            var childEnv = env
            childEnv["PERSONA_MODE"] = "1"
            proc.environment = childEnv
            try proc.run()
        }

        return cmd
    }
}

