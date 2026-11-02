import PersonaCore
import SwiftUI

private let clockTimeFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "HH:mm"
    return fmt
}()

private let clockDateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "EEE dd MMM"
    return fmt
}()

public struct ClockBadge: View {
    public init() {}

    public var body: some View {
        TimelineView(.periodic(from: Date(), by: 1.0)) { context in
            let date = context.date

            HStack(spacing: 6) {
                // Time
                Text(clockTimeFormatter.string(from: date))
                    .font(Fonts.display(18))
                    .foregroundColor(ThemeColors.white)

                // Date
                Text(clockDateFormatter.string(from: date).uppercased())
                    .font(Fonts.body(11, bold: true))
                    .foregroundColor(ThemeColors.cyan)
            }
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(
                SkewedPill()
                    .fill(ThemeColors.midnight.opacity(0.85))
                    .overlay(
                        SkewedPill()
                            .stroke(ThemeColors.cyan.opacity(0.4), lineWidth: 1)
                    )
            )
            .accessibilityIdentifier("topbar.clock")
        }
    }
}
