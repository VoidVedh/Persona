import Foundation

public enum MoonPhaseName: String, Codable, Equatable, CaseIterable {
    case new = "New"
    case waxingCrescent = "Waxing Crescent"
    case firstQuarter = "First Quarter"
    case waxingGibbous = "Waxing Gibbous"
    case full = "Full"
    case waningGibbous = "Waning Gibbous"
    case lastQuarter = "Last Quarter"
    case waningCrescent = "Waning Crescent"
}

/// Mean-synodic lunar cycle calculator for the P3R Moon Phase HUD widget (§7.2).
public struct MoonPhase: Codable, Equatable {
    public static let synodicMonthDays: Double = 29.530588853
    public static let epochJulianDate: Double = 2451550.26 // 2000-01-06 18:14 UTC new moon

    /// Lunar age in days `[0, 29.530588853)`.
    public let ageDays: Double
    /// Normalized phase fraction `p` in `[0, 1)`. `0` = New Moon, `0.5` = Full Moon.
    public let phase: Double
    /// Illuminated fraction in `[0, 1]`.
    public let illumination: Double
    /// 8-bin lunar phase name.
    public let name: MoonPhaseName
    /// Days remaining until the next Full Moon in `(0, 29.530588853]`.
    public let toFullDays: Double
    /// Formatted P3R countdown string (e.g. `"T-05D 14H"`).
    public let countdownText: String

    public init(
        ageDays: Double,
        phase: Double,
        illumination: Double,
        name: MoonPhaseName,
        toFullDays: Double,
        countdownText: String
    ) {
        self.ageDays = ageDays
        self.phase = phase
        self.illumination = illumination
        self.name = name
        self.toFullDays = toFullDays
        self.countdownText = countdownText
    }

    public static func compute(for date: Date) -> MoonPhase {
        let jd = date.timeIntervalSince1970 / 86400.0 + 2440587.5
        let rawDiff = jd - epochJulianDate
        var age = rawDiff.truncatingRemainder(dividingBy: synodicMonthDays)
        if age < 0 {
            age += synodicMonthDays
        }

        let p = max(0.0, min(0.999999999, age / synodicMonthDays))
        let illum = (1.0 - cos(2.0 * Double.pi * p)) / 2.0

        // 8 bins of width 0.125 centred on 0, 0.125, 0.25, ...
        let shifted = (p + 0.0625).truncatingRemainder(dividingBy: 1.0)
        let binIndex = Int(floor(shifted * 8.0)) % 8
        let allNames = MoonPhaseName.allCases
        let phaseName = allNames[max(0, min(allNames.count - 1, binIndex))]

        var toFull = (0.5 - p) * synodicMonthDays
        if toFull <= 0 {
            toFull += synodicMonthDays
        }

        let totalHours = max(0, Int(round(toFull * 24.0)))
        let days = totalHours / 24
        let hours = totalHours % 24
        let text = String(format: "T-%02dD %02dH", days, hours)

        return MoonPhase(
            ageDays: age,
            phase: p,
            illumination: illum,
            name: phaseName,
            toFullDays: toFull,
            countdownText: text
        )
    }
}

