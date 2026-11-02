import PersonaCore
import SwiftUI

public struct NowPlayingWidget: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        let np = appState.nowPlaying

        ZStack(alignment: .topTrailing) {
            // Panel background
            AngledPanel(cutSize: 14)
                .fill(ThemeColors.midnight.opacity(0.88))
                .overlay(
                    AngledPanel(cutSize: 14)
                        .stroke(ThemeColors.cyan.opacity(0.4), lineWidth: 1)
                )

            // Halftone accent in corner
            Halftone(dotColor: ThemeColors.cyan.opacity(0.18), spacing: 8, maxRadius: 2.5)
                .frame(width: 60, height: 40)
                .clipped()
                .padding(.top, 4)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 6) {
                // Header tag
                HStack(spacing: 6) {
                    Image(systemName: np?.state == .playing ? "music.note" : "music.note.list")
                        .foregroundColor(ThemeColors.cyan)
                    Text("NOW PLAYING")
                        .font(Fonts.display(12))
                        .foregroundColor(ThemeColors.cyan)

                    Spacer()

                    if np?.state == .playing {
                        equalizerBars()
                    }
                }

                if let current = np {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.title.isEmpty ? "Unknown Track" : current.title)
                            .font(Fonts.body(14, bold: true))
                            .foregroundColor(ThemeColors.white)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(current.artist.isEmpty ? current.source.uppercased() : current.artist)
                            .font(Fonts.body(12))
                            .foregroundColor(ThemeColors.ice.opacity(0.75))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("— NOTHING PLAYING —")
                        .font(Fonts.body(13))
                        .foregroundColor(ThemeColors.steel)
                        .padding(.vertical, 4)
                }
            }
            .padding(14)
        }
        .frame(width: 260, height: 90)
    }

    @ViewBuilder
    private func equalizerBars() -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 8.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    let h = 4.0 + 8.0 * abs(sin(phase * 4.0 + Double(i) * 1.5))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ThemeColors.cyan)
                        .frame(width: 2.5, height: CGFloat(h))
                }
            }
            .frame(height: 14)
        }
    }
}
