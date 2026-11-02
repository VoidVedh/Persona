import Foundation
import PersonaCore

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
        }
    }
}
