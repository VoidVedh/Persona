import AppKit
import PersonaCore
import SwiftUI

private final class HoverBox: ObservableObject {
    @Published var isHovered = false
}

public struct QuitButton: View {
    @StateObject private var hoverBox = HoverBox()

    public var onQuit: (() -> Void)?

    public init(onQuit: (() -> Void)? = nil) {
        self.onQuit = onQuit
    }

    public var body: some View {
        Button(action: {
            if let custom = onQuit {
                custom()
            } else {
                NotificationCenter.default.post(
                    name: NSNotification.Name("dev.persona.mode.exit"),
                    object: nil
                )
            }
        }) {
            ZStack {
                SkewedPill()
                    .fill(hoverBox.isHovered ? ThemeColors.alert.opacity(0.8) : ThemeColors.alert.opacity(0.25))
                    .overlay(
                        SkewedPill()
                            .stroke(ThemeColors.alert, lineWidth: 1.2)
                    )

                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                    Text("QUIT")
                        .font(Fonts.display(13))
                }
                .foregroundColor(ThemeColors.white)
                .padding(.horizontal, 8)
            }
            .frame(height: 22)
            .shadow(color: hoverBox.isHovered ? ThemeColors.alert.opacity(0.6) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .onHover { hoverBox.isHovered = $0 }
        .help("Return to macOS")
        .accessibilityIdentifier("topbar.quit")
    }
}
