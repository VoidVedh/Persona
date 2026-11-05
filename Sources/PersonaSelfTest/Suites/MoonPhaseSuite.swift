import Foundation
import PersonaCore

public enum MoonPhaseSuite {
    public static func run(_ t: Harness) {
        t.suite("moonphase") {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 0)!

            func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
                var c = DateComponents()
                c.year = year
                c.month = month
                c.day = day
                c.hour = hour
                c.minute = minute
                c.second = 0
                return cal.date(from: c)!
            }

            // 1. New Moon: 2024-01-11 11:57 UTC -> p within 0.026 of 0 (or 1)
            let newMoonDate = utcDate(2024, 1, 11, 11, 57)
            let nm = MoonPhase.compute(for: newMoonDate)
            let nmDist = min(nm.phase, 1.0 - nm.phase)
            t.expect(nmDist <= 0.026, "2024-01-11 11:57 UTC new moon p within 0.026 of 0/1 (got \(nm.phase))")
            t.expectEqual(nm.name, .new, "2024-01-11 11:57 UTC classified as New Moon")
            t.expect(nm.illumination < 0.02, "new moon illumination < 2%")

            // 2. Full Moon: 2024-01-25 17:54 UTC -> p within 0.026 of 0.5
            let fullMoonDate = utcDate(2024, 1, 25, 17, 54)
            let fm = MoonPhase.compute(for: fullMoonDate)
            let fmDist = abs(fm.phase - 0.5)
            t.expect(fmDist <= 0.026, "2024-01-25 17:54 UTC full moon p within 0.026 of 0.5 (got \(fm.phase))")
            t.expectEqual(fm.name, .full, "2024-01-25 17:54 UTC classified as Full Moon")
            t.expect(fm.illumination > 0.98, "full moon illumination > 98%")

            // 3. Monotonic illumination over waxing half-cycle from epoch new moon
            let epochDate = Date(timeIntervalSince1970: (MoonPhase.epochJulianDate - 2440587.5) * 86400.0)
            var prevIllum = -1.0
            var waxingMonotonic = true
            for step in 0...14 {
                let d = epochDate.addingTimeInterval(Double(step) * 86400.0)
                let m = MoonPhase.compute(for: d)
                if m.illumination < prevIllum - 1e-9 {
                    waxingMonotonic = false
                }
                prevIllum = m.illumination
            }
            t.expect(waxingMonotonic, "illumination increases monotonically from new moon to full moon")

            // 4. toFullDays in (0, 29.530588853] across 1000 dates
            var allInBounds = true
            var allFormatted = true
            let base = utcDate(2020, 1, 1, 0, 0)
            for i in 0..<1000 {
                let d = base.addingTimeInterval(Double(i) * 31987.0)
                let m = MoonPhase.compute(for: d)
                if !(m.toFullDays > 0.0 && m.toFullDays <= MoonPhase.synodicMonthDays + 1e-6) {
                    allInBounds = false
                }
                if !m.countdownText.hasPrefix("T-") || !m.countdownText.hasSuffix("H") {
                    allFormatted = false
                }
            }
            t.expect(allInBounds, "toFullDays in (0, 29.53] across 1000 dates")
            t.expect(allFormatted, "countdownText matches T-xxD xxH format across 1000 dates")
        }
    }
}

