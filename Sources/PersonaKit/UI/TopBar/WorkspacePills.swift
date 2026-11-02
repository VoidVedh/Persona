import PersonaCore
import SwiftUI

public struct WorkspacePills: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        let pills = SpaceLayout.pills(for: appState.spaceSnapshot)

        HStack(spacing: 5) {
            ForEach(pills, id: \.index) { pill in
                Button(action: {
                    SpaceProvider.shared.switchTo(spaceIndex: pill.index)
                }) {
                    ZStack {
                        if pill.isActive {
                            SkewedPill()
                                .fill(ThemeColors.cyan)
                                .shadow(color: ThemeColors.cyan.opacity(0.8), radius: 6, x: 0, y: 0)
                            Text("\(pill.index)")
                                .font(Fonts.display(14))
                                .foregroundColor(ThemeColors.midnight)
                        } else {
                            SkewedPill()
                                .stroke(ThemeColors.steel, lineWidth: 1.2)
                                .background(SkewedPill().fill(ThemeColors.midnight.opacity(0.6)))
                            Text("\(pill.index)")
                                .font(Fonts.display(14))
                                .foregroundColor(ThemeColors.ice.opacity(0.7))
                        }
                    }
                    .frame(width: 26, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("topbar.space.\(pill.index)")
            }
        }
    }
}
