import AppKit
import Foundation
import PersonaCore
import PersonaKit

public enum ThemeSuite {
    public static func run(_ t: Harness) {
        t.suite("theme") {
            // Hex parsing
            t.expectEqual(ThemeTokens.rgb(hex: "#00d8ff"), ThemeTokens.RGB(r: 0, g: 216 / 255.0, b: 1), "parse cyan")
            t.expectEqual(ThemeTokens.rgb(hex: "#0a192f"), ThemeTokens.RGB(r: 10 / 255.0, g: 25 / 255.0, b: 47 / 255.0), "parse midnight")
            t.expect(ThemeTokens.rgb(hex: "invalid") == nil, "invalid hex returns nil")

            // Contrast ratios (WCAG AAA >= 7.0 for normal text on dark midnight background)
            if let cyanOnMidnight = ThemeTokens.contrastRatio(ThemeTokens.cyan, ThemeTokens.midnight) {
                t.expect(cyanOnMidnight >= 7.0, "cyan on midnight contrast >= 7.0 (got \(cyanOnMidnight))")
            } else {
                t.fail("failed to calculate contrast ratio for cyan on midnight")
            }

            if let iceOnMidnight = ThemeTokens.contrastRatio(ThemeTokens.ice, ThemeTokens.midnight) {
                t.expect(iceOnMidnight >= 7.0, "ice on midnight contrast >= 7.0 (got \(iceOnMidnight))")
            } else {
                t.fail("failed to calculate contrast ratio for ice on midnight")
            }

            // Dark Hour phase calculations
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!

            func dateAt(hour: Int, minute: Int) -> Date {
                var comp = DateComponents()
                comp.year = 2026
                comp.month = 10
                comp.day = 26
                comp.hour = hour
                comp.minute = minute
                return cal.date(from: comp)!
            }

            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 0, minute: 0), calendar: cal), .darkHour, "00:00 is Dark Hour")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 0, minute: 59), calendar: cal), .darkHour, "00:59 is Dark Hour")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 1, minute: 0), calendar: cal), .lateNight, "01:00 is late night")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 7, minute: 30), calendar: cal), .earlyMorning, "07:30 is early morning")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 12, minute: 0), calendar: cal), .daytime, "12:00 is daytime")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 19, minute: 0), calendar: cal), .evening, "19:00 is evening")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 23, minute: 59), calendar: cal), .lateNight, "23:59 is late night")

            // Forced overrides
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 12, minute: 0), calendar: cal, force: true), .darkHour, "force=true yields Dark Hour")
            t.expectEqual(DarkHourPhase.phase(for: dateAt(hour: 0, minute: 30), calendar: cal, force: false), .lateNight, "force=false suppresses Dark Hour")

            // Pill severity
            t.expectEqual(PillSeverity.forUsage(50.0), .normal, "50% usage is normal")
            t.expectEqual(PillSeverity.forUsage(85.0), .warn, "85% usage is warn")
            t.expectEqual(PillSeverity.forBattery(percent: 15.0, charging: false), .alert, "15% not charging is alert")
            t.expectEqual(PillSeverity.forBattery(percent: 15.0, charging: true), .normal, "15% charging is normal")

            // Space layout pill fallback
            let fallbackPills = SpaceLayout.pills(for: .unavailable)
            t.expectEqual(fallbackPills.count, 1, "unavailable spaces produces 1 fallback pill")
            t.expectEqual(fallbackPills[0].index, 1, "fallback pill is index 1")
            t.expect(fallbackPills[0].isActive, "fallback pill is active")

            // NowPlaying parser
            let trackInfo = NowPlayingParser.parse(
                notification: NowPlayingParser.spotifyNotification,
                userInfo: [
                    "Player State": "Playing",
                    "Name": "Color Your Night",
                    "Artist": "Azumi Takahashi",
                    "Album": "P3R OST"
                ]
            )
            t.expectEqual(trackInfo?.state, .playing, "parsed state is playing")
            t.expectEqual(trackInfo?.title, "Color Your Night", "parsed title")
            t.expectEqual(trackInfo?.artist, "Azumi Takahashi", "parsed artist")

            let seed = NowPlayingParser.parseSeed(source: "music", output: "Full Moon Full Life\tLotus Juice\tplaying\n")
            t.expectEqual(seed?.title, "Full Moon Full Life", "parsed seed title")
            t.expectEqual(seed?.state, .playing, "parsed seed state")

            // Phase 6.1: Validate hex colors across all static terminal & CLI profiles against ThemeTokens
            if let profilesDir = ProfileRenderer.resolveSourceProfilesDir() {
                let textProfileFiles = [
                    "fastfetch/config.jsonc",
                    "ghostty/config",
                    "kitty/kitty.conf",
                    "wezterm/wezterm.lua",
                    "alacritty/alacritty.toml",
                    "cava/config"
                ]
                let regex = try? NSRegularExpression(pattern: "#[0-9a-fA-F]{6}", options: [])
                for rel in textProfileFiles {
                    let fileURL = profilesDir.appendingPathComponent(rel)
                    let exists = FileManager.default.fileExists(atPath: fileURL.path)
                    t.expect(exists, "profile exists: \(rel)")
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8),
                       let regex = regex {
                        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
                        let matches = regex.matches(in: content, options: [], range: nsRange)
                        t.expect(!matches.isEmpty, "profile \(rel) contains hex colors")
                        for m in matches {
                            if let r = Range(m.range, in: content) {
                                let hex = String(content[r]).lowercased()
                                t.expect(
                                    ThemeTokens.terminalAllowedHexSet.contains(hex),
                                    "color \(hex) in \(rel) is in ThemeTokens.terminalAllowedHexSet"
                                )
                            }
                        }
                    }
                }
            } else {
                t.fail("Could not locate Resources/profiles directory")
            }

            // Phase 6.1: TerminalAppProfile plist generation
            if let plistData = try? TerminalAppProfile.generatePlistData(),
               let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                t.expectEqual(plist["name"] as? String, "Persona 3 Reload", "Terminal.app profile name")
                t.expectEqual(plist["type"] as? String, "Window Settings", "Terminal.app profile type")
                t.expect(plist["BackgroundColor"] is Data, "Terminal.app BackgroundColor encoded as Data")
                t.expect(plist["CursorColor"] is Data, "Terminal.app CursorColor encoded as Data")
            } else {
                t.fail("TerminalAppProfile.generatePlistData() failed")
            }

            // Phase 6.2: ProfileRenderer renders into isolated $TMPDIR/PersonaMode/profiles and cleans up
            if let renderedDir = try? ProfileRenderer.shared.render(mutator: nil) {
                let ffConfig = renderedDir.appendingPathComponent("fastfetch/config.jsonc")
                let runCmd = renderedDir.appendingPathComponent("run.command")
                let termFile = renderedDir.appendingPathComponent("terminal-app/Persona3Reload.terminal")
                t.expect(FileManager.default.fileExists(atPath: ffConfig.path), "rendered fastfetch/config.jsonc exists")
                t.expect(FileManager.default.fileExists(atPath: runCmd.path), "rendered run.command exists")
                t.expect(FileManager.default.fileExists(atPath: termFile.path), "rendered Persona3Reload.terminal exists")

                if let text = try? String(contentsOf: ffConfig, encoding: .utf8) {
                    t.expect(!text.contains("{{PROFILE_DIR}}"), "{{PROFILE_DIR}} placeholder substituted in fastfetch/config.jsonc")
                    t.expect(text.contains(renderedDir.path), "fastfetch/config.jsonc contains rendered absolute path")
                }

                ProfileRenderer.shared.cleanup()
                t.expect(!FileManager.default.fileExists(atPath: renderedDir.path), "ProfileRenderer.cleanup() removes rendered directory")
            } else {
                t.fail("ProfileRenderer.render() failed")
            }

            // Phase 6.3: TerminalLauncher detection & isolated command generation
            let detected = TerminalLauncher.shared.detect()
            t.expect(!detected.chosen.isEmpty, "TerminalLauncher detects a terminal (\(detected.chosen))")
            t.expect(detected.available.contains("terminal"), "Terminal.app is always available as fallback")

            let dummyProfileDir = URL(fileURLWithPath: "/tmp/PersonaMode/profiles")
            let ghosttyCmd = TerminalLauncher.shared.buildCommand(chosen: "ghostty", profileDir: dummyProfileDir)
            t.expect(ghosttyCmd.contains("--config-default-files=false"), "ghostty uses --config-default-files=false")
            let kittyCmd = TerminalLauncher.shared.buildCommand(chosen: "kitty", profileDir: dummyProfileDir)
            t.expect(kittyCmd.contains("--config"), "kitty uses isolated --config")

            // Phase 6.4: StatusBarController menu items & lifecycle
            MainActor.assumeIsolated {
                _ = NSApplication.shared
                StatusBarController.shared.start()
                t.expect(StatusBarController.shared.isInstalled, "StatusBarController installed after start()")
                let titles = (StatusBarController.shared.menu?.items ?? []).map { $0.title }
                t.expect(titles.contains("Open P3R Launcher"), "Status menu has 'Open P3R Launcher'")
                t.expect(titles.contains("Retile Windows Now"), "Status menu has 'Retile Windows Now'")
                t.expect(titles.contains("Toggle Active Window Float"), "Status menu has 'Toggle Active Window Float'")
                t.expect(titles.contains("Open Terminal (P3R)"), "Status menu has 'Open Terminal (P3R)'")
                t.expect(titles.contains("Return to macOS (Quit)"), "Status menu has 'Return to macOS (Quit)'")
                StatusBarController.shared.stop()
                t.expect(!StatusBarController.shared.isInstalled, "StatusBarController removed after stop()")
            }
        }
    }
}
