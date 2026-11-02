import PersonaCore
import SwiftUI

public struct TopBarView: View {
    public var screen: ScreenModel
    public var config: TopBarConfig
    public var onQuit: (() -> Void)?

    public init(screen: ScreenModel, config: TopBarConfig = TopBarConfig(), onQuit: (() -> Void)? = nil) {
        self.screen = screen
        self.config = config
        self.onQuit = onQuit
    }

    public var body: some View {
        let split = WindowGeometry.clusterSplit(
            barFrame: WindowGeometry.barFrame(screenFrame: screen.frame, safeTop: screen.safeTop, config: config),
            auxLeft: screen.auxLeft,
            auxRight: screen.auxRight
        )

        ZStack {
            // Background angled panel
            AngledPanel(cutSize: 8)
                .fill(ThemeColors.midnight.opacity(0.92))
                .overlay(
                    AngledPanel(cutSize: 8)
                        .stroke(ThemeColors.cyan.opacity(0.4), lineWidth: 1)
                )

            // Cyan tick accent at left edge
            HStack {
                Rectangle()
                    .fill(ThemeColors.cyan)
                    .frame(width: 3, height: 18)
                    .padding(.leading, 4)
                Spacer()
            }

            // Clusters content
            if let split = split {
                HStack(spacing: 0) {
                    leftCluster()
                        .frame(width: split.leftWidth, alignment: .leading)
                        .padding(.leading, 8)

                    Spacer(minLength: split.gap)

                    rightCluster()
                        .frame(width: split.rightWidth, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            } else {
                HStack {
                    leftCluster()
                        .padding(.leading, 8)

                    Spacer()

                    rightCluster()
                        .padding(.trailing, 8)
                }
            }
        }
        .frame(height: WindowGeometry.barHeight(configHeight: config.height, safeTop: screen.safeTop))
    }

    @ViewBuilder
    private func leftCluster() -> some View {
        HStack(spacing: 10) {
            WorkspacePills()
            FocusLabel()
        }
    }

    @ViewBuilder
    private func rightCluster() -> some View {
        HStack(spacing: 8) {
            TelemetryPills()
            ClockBadge()
            QuitButton(onQuit: onQuit)
        }
    }
}
