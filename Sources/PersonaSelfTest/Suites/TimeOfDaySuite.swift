import Foundation
import PersonaCore

public enum TimeOfDaySuite {
    public static func run(_ t: Harness) {
        t.suite("timeofday") {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!

            func makeDate(hour: Int, minute: Int) -> Date {
                var comps = DateComponents()
                comps.year = 2026
                comps.month = 11
                comps.day = 5
                comps.hour = hour
                comps.minute = minute
                comps.second = 0
                return cal.date(from: comps)!
            }

            let cases: [(Int, Int, TimeOfDaySlot, String)] = [
                (0, 0, .darkHour, "DARK HOUR"),
                (0, 59, .darkHour, "DARK HOUR"),
                (1, 0, .lateNight, "LATE NIGHT"),
                (4, 59, .lateNight, "LATE NIGHT"),
                (5, 0, .earlyMorning, "EARLY MORNING"),
                (6, 59, .earlyMorning, "EARLY MORNING"),
                (7, 0, .morning, "MORNING"),
                (11, 59, .morning, "MORNING"),
                (12, 0, .lunchtime, "LUNCHTIME"),
                (12, 59, .lunchtime, "LUNCHTIME"),
                (13, 0, .afternoon, "AFTERNOON"),
                (15, 59, .afternoon, "AFTERNOON"),
                (16, 0, .afterSchool, "AFTER SCHOOL"),
                (17, 59, .afterSchool, "AFTER SCHOOL"),
                (18, 0, .evening, "EVENING"),
                (21, 59, .evening, "EVENING"),
                (22, 0, .lateNight, "LATE NIGHT"),
                (23, 59, .lateNight, "LATE NIGHT"),
            ]

            for (h, m, expectedSlot, expectedLabel) in cases {
                let d = makeDate(hour: h, minute: m)
                let slot = TimeOfDaySlot.slot(for: d, calendar: cal)
                let tag = String(format: "%02d:%02d", h, m)
                t.expectEqual(slot, expectedSlot, "\(tag) -> \(expectedSlot.rawValue)")
                t.expectEqual(slot.label, expectedLabel, "\(tag) label == \(expectedLabel)")
            }

            // Force overrides
            let afternoon = makeDate(hour: 15, minute: 30)
            t.expectEqual(
                TimeOfDaySlot.slot(for: afternoon, calendar: cal, force: true),
                .darkHour,
                "force=true pins DARK HOUR at 15:30"
            )

            let midnight = makeDate(hour: 0, minute: 15)
            t.expectEqual(
                TimeOfDaySlot.slot(for: midnight, calendar: cal, force: false),
                .lateNight,
                "force=false demotes DARK HOUR to LATE NIGHT at 00:15"
            )
        }
    }
}

