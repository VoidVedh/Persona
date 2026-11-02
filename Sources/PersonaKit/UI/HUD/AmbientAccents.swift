import PersonaCore
import SwiftUI

public struct AmbientAccents: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        if appState.ambientPaused {
            staticAccents()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 5.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                accents(time: time)
            }
        }
    }

    private func staticAccents() -> some View {
        accents(time: 0)
    }

    private func accents(time: Double) -> some View {
        let isDarkHour = appState.darkHourPhase == .darkHour
        let accentColor = isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Rotating Hex Ring 1 (Center-Left)
                HexRing(rotation: .degrees(time * 6.0))
                    .stroke(accentColor.opacity(0.12), lineWidth: 1.5)
                    .frame(width: 220, height: 220)
                    .position(x: w * 0.3, y: h * 0.55)

                // Counter-rotating Inner Hex Ring
                HexRing(rotation: .degrees(-time * 9.0))
                    .stroke(accentColor.opacity(0.08), lineWidth: 1.0)
                    .frame(width: 160, height: 160)
                    .position(x: w * 0.3, y: h * 0.55)

                // Diagonal light drift lines (Persona 3 style)
                Canvas { context, size in
                    let offset = CGFloat(fmod(time * 25.0, 120.0))
                    var path = Path()
                    var x: CGFloat = -size.height + offset
                    while x < size.width + size.height {
                        path.move(to: CGPoint(x: x, y: size.height))
                        path.addLine(to: CGPoint(x: x + size.height * 0.6, y: 0))
                        x += 180
                    }
                    context.stroke(
                        path,
                        with: .color(accentColor.opacity(0.04)),
                        lineWidth: 1.5
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
