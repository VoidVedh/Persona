import Foundation

/// Authentic 8-slot Persona 3 Reload time-of-day banner model (§7.1).
public enum TimeOfDaySlot: String, Codable, Equatable, CaseIterable {
    case darkHour
    case lateNight
    case earlyMorning
    case morning
    case lunchtime
    case afternoon
    case afterSchool
    case evening

    /// Uppercase P3R HUD banner label.
    public var label: String {
        switch self {
        case .darkHour: return "DARK HOUR"
        case .lateNight: return "LATE NIGHT"
        case .earlyMorning: return "EARLY MORNING"
        case .morning: return "MORNING"
        case .lunchtime: return "LUNCHTIME"
        case .afternoon: return "AFTERNOON"
        case .afterSchool: return "AFTER SCHOOL"
        case .evening: return "EVENING"
        }
    }

    /// Primary CSS accent token name for this time-of-day slot (§6.4 C).
    public var accentToken: String {
        switch self {
        case .darkHour:
            return "--dark"
        case .evening:
            return "--azure"
        case .lateNight:
            return "--royal"
        case .earlyMorning, .morning, .lunchtime, .afternoon, .afterSchool:
            return "--cyan"
        }
    }

    /// Computes the P3R time-of-day slot for `date`.
    /// - `00:00–00:59`: `DARK HOUR`
    /// - `01:00–04:59`: `LATE NIGHT`
    /// - `05:00–06:59`: `EARLY MORNING`
    /// - `07:00–11:59`: `MORNING`
    /// - `12:00–12:59`: `LUNCHTIME`
    /// - `13:00–15:59`: `AFTERNOON`
    /// - `16:00–17:59`: `AFTER SCHOOL`
    /// - `18:00–21:59`: `EVENING`
    /// - `22:00–23:59`: `LATE NIGHT`
    /// - `force == true` pins `.darkHour`; `force == false` demotes `.darkHour` to `.lateNight`.
    public static func slot(
        for date: Date,
        calendar: Calendar = .current,
        force: Bool? = nil
    ) -> TimeOfDaySlot {
        if force == true {
            return .darkHour
        }
        let hour = calendar.component(.hour, from: date)
        let natural: TimeOfDaySlot
        switch hour {
        case 0:
            natural = .darkHour
        case 1...4:
            natural = .lateNight
        case 5...6:
            natural = .earlyMorning
        case 7...11:
            natural = .morning
        case 12:
            natural = .lunchtime
        case 13...15:
            natural = .afternoon
        case 16...17:
            natural = .afterSchool
        case 18...21:
            natural = .evening
        default:
            natural = .lateNight
        }
        if force == false && natural == .darkHour {
            return .lateNight
        }
        return natural
    }
}

