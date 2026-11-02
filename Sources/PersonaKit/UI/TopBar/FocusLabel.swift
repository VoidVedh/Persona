import PersonaCore
import SwiftUI

public struct FocusLabel: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            // App Name tag
            ZStack {
                SkewedPill()
                    .fill(ThemeColors.royalBlue.opacity(0.85))
                    .overlay(
                        SkewedPill()
                            .stroke(ThemeColors.cyan.opacity(0.5), lineWidth: 1)
                    )
                Text(appState.focusedApp)
                    .font(Fonts.display(14))
                    .foregroundColor(ThemeColors.white)
                    .padding(.horizontal, 10)
            }
            .frame(height: 22)

            // Window Title
            if !appState.focusedTitle.isEmpty {
                Text(appState.focusedTitle)
                    .font(Fonts.body(13))
                    .foregroundColor(ThemeColors.ice.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }
}
