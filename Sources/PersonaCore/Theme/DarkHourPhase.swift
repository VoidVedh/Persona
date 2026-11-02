import Foundation

/// Time-of-day phase driving the HUD tag and moon glow (§8.2).
public enum DarkHourPhase: String, Codable, Equatable, CaseIterable {
    case darkHour
    case earlyMorning
    case daytime
    case evening
    case lateNight

    /// Label shown in the HUD chip.
    public var label: String {
        switch self {
        case .darkHour: return "DARK HOUR"
        case .earlyMorning: return "EARLY MORNING"
        case .daytime: return "DAYTIME"
        case .evening: return "EVENING"
        case .lateNight: return "LATE NIGHT"
        }
    }

    /// Phase for `date`.
    ///
    /// - `00:00–00:59` Dark Hour · `01–04` late night · `05–09` early morning · `10–16` daytime ·
    ///   `17–21` evening · `22–23` late night.
    /// - `force == true` pins `.darkHour` (demo); `force == false` suppresses the Dark Hour
    ///   (it degrades to `.lateNight`); `nil` follows the clock.
    public static func phase(for date: Date, calendar: Calendar = .current, force: Bool? = nil) -> DarkHourPhase {
        if force == true { return .darkHour }
        let hour = calendar.component(.hour, from: date)
        let natural: DarkHourPhase
        switch hour {
        case 0: natural = .darkHour
        case 1...4: natural = .lateNight
        case 5...9: natural = .earlyMorning
        case 10...16: natural = .daytime
        case 17...21: natural = .evening
        default: natural = .lateNight
        }
        if force == false && natural == .darkHour { return .lateNight }
        return natural
    }
}
