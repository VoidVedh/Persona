import AppKit
import Foundation
import PersonaCore

/// Generates and cleans up the fallback macOS `Terminal.app` settings profile (`Persona3Reload.terminal`).
public enum TerminalAppProfile {
    public static let profileName = "Persona 3 Reload"

    /// Encodes an `#rrggbb` hex string as `NSKeyedArchiver` `NSColor` data for `Terminal.app`.
    public static func archivedColor(hex: String, alpha: CGFloat = 1.0) -> Data? {
        guard let rgb = ThemeTokens.rgb(hex: hex) else { return nil }
        let color = NSColor(
            srgbRed: CGFloat(rgb.r),
            green: CGFloat(rgb.g),
            blue: CGFloat(rgb.b),
            alpha: alpha
        )
        return try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false)
    }

    /// Generates the complete XML PropertyList data for `Persona3Reload.terminal`.
    public static func generatePlistData() throws -> Data {
        var dict: [String: Any] = [
            "name": profileName,
            "type": "Window Settings",
            "ProfileCurrentVersion": 2.07,
            "WindowTitle": "PERSONA // DARK HOUR",
            "columnCount": 100,
            "rowCount": 30,
            "BackgroundAlphaInactive": 0.92,
            "BackgroundSettingsForInactiveWindows": false,
            "BackgroundBlur": 0.35,
            "CursorType": 0,
            "CursorBlink": true,
            "useOptionAsMetaKey": true
        ]

        let colorMappings: [(key: String, hex: String, alpha: CGFloat)] = [
            ("BackgroundColor", ThemeTokens.midnight, 0.92),
            ("TextColor", ThemeTokens.ice, 1.0),
            ("TextBoldColor", ThemeTokens.white, 1.0),
            ("CursorColor", ThemeTokens.cyan, 1.0),
            ("SelectionColor", ThemeTokens.azure, 1.0),
            ("ANSIBlackColor", ThemeTokens.midnight, 1.0),
            ("ANSIRedColor", ThemeTokens.alert, 1.0),
            ("ANSIGreenColor", ThemeTokens.darkHour, 1.0),
            ("ANSIYellowColor", ThemeTokens.warn, 1.0),
            ("ANSIBlueColor", ThemeTokens.azure, 1.0),
            ("ANSIMagentaColor", "#b48cff", 1.0),
            ("ANSICyanColor", ThemeTokens.cyan, 1.0),
            ("ANSIWhiteColor", ThemeTokens.ice, 1.0),
            ("ANSIBrightBlackColor", ThemeTokens.steel, 1.0),
            ("ANSIBrightRedColor", "#ff6b85", 1.0),
            ("ANSIBrightGreenColor", "#8cffdf", 1.0),
            ("ANSIBrightYellowColor", "#ffe07d", 1.0),
            ("ANSIBrightBlueColor", "#4d8bff", 1.0),
            ("ANSIBrightMagentaColor", "#ccaeff", 1.0),
            ("ANSIBrightCyanColor", "#5ce5ff", 1.0),
            ("ANSIBrightWhiteColor", ThemeTokens.white, 1.0)
        ]

        for mapping in colorMappings {
            if let data = archivedColor(hex: mapping.hex, alpha: mapping.alpha) {
                dict[mapping.key] = data
            }
        }

        let font = NSFont(name: "Menlo-Regular", size: 13.0) ?? NSFont.monospacedSystemFont(ofSize: 13.0, weight: .regular)
        if let fontData = try? NSKeyedArchiver.archivedData(withRootObject: font, requiringSecureCoding: false) {
            dict["Font"] = fontData
        }

        return try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
    }

    /// Writes `Persona3Reload.terminal` to the specified URL.
    public static func writeProfile(to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try generatePlistData()
        try data.write(to: url, options: .atomic)
    }

    /// Removes the temporary `Persona 3 Reload` settings set from `Terminal.app` preferences (Spike S-6).
    /// Never launches `Terminal.app` if it is not already running.
    public static func removeInstalledProfile(named name: String = profileName) {
        let env = ProcessInfo.processInfo.environment
        if env["PERSONA_DRY_RUN"] == "1" && env["PERSONA_LAUNCH_TERMINAL_LIVE"] != "1" {
            return
        }

        // 1. If Terminal.app is currently running, remove from live in-memory settings set via AppleScript
        let isTerminalRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Terminal").isEmpty
        if isTerminalRunning {
            let script = """
            tell application "Terminal"
                try
                    delete (every settings set whose name is "\(name)")
                end try
            end tell
            """
            var err: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                _ = appleScript.executeAndReturnError(&err)
            }
        }

        // 2. Always remove from com.apple.Terminal.plist via PlistBuddy + CFPreferences synchronize
        let plistPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Preferences/com.apple.Terminal.plist")
        if FileManager.default.fileExists(atPath: plistPath) {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/libexec/PlistBuddy")
            proc.arguments = ["-c", "Delete :'Window Settings':'\(name)'", plistPath]
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()
        }
        CFPreferencesAppSynchronize("com.apple.Terminal" as CFString)
    }
}

