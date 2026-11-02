import PersonaCore
import SwiftUI

private let hudTimeFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"
    return fmt
}()

private let hudWeekdayFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "EEEE"
    return fmt
}()

private let hudFullDateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "dd MMMM yyyy"
    return fmt
}()

public struct DateTimeWidget: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
            let date = context.date
            let phase = appState.darkHourPhase
            let isDarkHour = phase == .darkHour

            ZStack(alignment: .topLeading) {
                // Background panel
                AngledPanel(cutSize: 16)
                    .fill(ThemeColors.midnight.opacity(0.88))
                    .overlay(
                        AngledPanel(cutSize: 16)
                            .stroke(
                                isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan.opacity(0.4),
                                lineWidth: isDarkHour ? 1.5 : 1.0
                            )
                    )

                VStack(alignment: .trailing, spacing: 4) {
                    // Phase Tag Chip
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan)
                            .frame(width: 6, height: 6)
                        Text(phase.label)
                            .font(Fonts.display(11))
                            .foregroundColor(isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        SkewedPill()
                            .fill(ThemeColors.abyss.opacity(0.7))
                    )

                    // Big Clock
                    Text(hudTimeFormatter.string(from: date))
                        .font(Fonts.display(48))
                        .foregroundColor(ThemeColors.white)
                        .shadow(color: isDarkHour ? ThemeColors.darkHour.opacity(0.5) : ThemeColors.cyan.opacity(0.4), radius: 8)

                    // Date & Weekday
                    HStack(spacing: 6) {
                        Text(hudWeekdayFormatter.string(from: date).uppercased())
                            .font(Fonts.display(15))
                            .foregroundColor(isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan)
                        Text(hudFullDateFormatter.string(from: date).uppercased())
                            .font(Fonts.body(13, bold: true))
                            .foregroundColor(ThemeColors.ice.opacity(0.85))
                    }
                }
                .padding(16)
            }
            .frame(width: 250, height: 130)
        }
    }
}
