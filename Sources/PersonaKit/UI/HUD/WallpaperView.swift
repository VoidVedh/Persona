import PersonaCore
import SwiftUI

public struct WallpaperView: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        let isDarkHour = appState.darkHourPhase == .darkHour
        let glowColor = isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan

        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [
                        ThemeColors.abyss,
                        ThemeColors.midnight,
                        Color(hex: "#040812")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Large Crescent Moon (top-center/left)
                crescentMoon(center: CGPoint(x: w * 0.45, y: h * 0.38), radius: min(w, h) * 0.22, glowColor: glowColor)

                // Background subtle hex grid pattern
                Canvas { context, size in
                    let step: CGFloat = 80
                    var path = Path()
                    var y: CGFloat = 0
                    while y < size.height {
                        var x: CGFloat = 0
                        while x < size.width {
                            let rect = CGRect(x: x, y: y, width: 30, height: 30)
                            path.addEllipse(in: rect)
                            x += step
                        }
                        y += step
                    }
                    context.stroke(path, with: .color(glowColor.opacity(0.02)), lineWidth: 0.8)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func crescentMoon(center: CGPoint, radius: CGFloat, glowColor: Color) -> some View {
        ZStack {
            // Radial Glow Behind Moon
            RadialGradient(
                colors: [
                    glowColor.opacity(0.35),
                    glowColor.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: radius * 0.5,
                endRadius: radius * 1.8
            )
            .frame(width: radius * 3.6, height: radius * 3.6)
            .position(center)

            // Crescent Moon Shape (Two overlapping circles via even-odd rule)
            Path { path in
                let outerRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                path.addEllipse(in: outerRect)

                let innerOffset = radius * 0.35
                let innerRadius = radius * 0.92
                let innerRect = CGRect(
                    x: center.x - innerRadius + innerOffset,
                    y: center.y - innerRadius - innerOffset * 0.3,
                    width: innerRadius * 2,
                    height: innerRadius * 2
                )
                path.addEllipse(in: innerRect)
            }
            .fill(
                LinearGradient(
                    colors: [
                        glowColor.opacity(0.9),
                        ThemeColors.ice.opacity(0.8),
                        ThemeColors.royalBlue.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                style: FillStyle(eoFill: true)
            )
            .shadow(color: glowColor.opacity(0.7), radius: 16)
        }
    }
}
