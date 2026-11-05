import PersonaCore
import SwiftUI

public struct AmbientAccents: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        let isDarkHour = appState.darkHourPhase == .darkHour
        let accentColor = isDarkHour ? ThemeColors.darkHour : ThemeColors.cyan

        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Static diagonal light lines (rendered once at startup, zero per-frame GPU texture allocation)
                Canvas { context, size in
                    var path = Path()
                    var x: CGFloat = -size.height
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

                if appState.ambientPaused {
                    hexRings(time: 0, accentColor: accentColor)
                        .position(x: w * 0.3, y: h * 0.55)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0)) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        hexRings(time: time, accentColor: accentColor)
                    }
                    .frame(width: 240, height: 240)
                    .position(x: w * 0.3, y: h * 0.55)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func hexRings(time: Double, accentColor: Color) -> some View {
        ZStack {
            HexRing(rotation: .zero)
                .stroke(accentColor.opacity(0.12), lineWidth: 1.5)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(time * 6.0))

            HexRing(rotation: .zero)
                .stroke(accentColor.opacity(0.08), lineWidth: 1.0)
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-time * 9.0))
        }
    }
}
