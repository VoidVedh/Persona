import PersonaCore
import SwiftUI

public struct HUDView: View {
    public var screen: ScreenModel
    public var config: AppConfig

    public init(screen: ScreenModel, config: AppConfig = AppConfig()) {
        self.screen = screen
        self.config = config
    }

    public var body: some View {
        ZStack {
            // Background Wallpaper
            if config.wallpaper.mode == .overlay {
                WallpaperView()
            }

            // Ambient Accents
            if config.hud.ambientAnimation {
                AmbientAccents()
            }

            // Widgets Layout
            VStack {
                // Top area: reserve top bar height + margin
                let topOffset = WindowGeometry.barHeight(configHeight: config.topBar.height, safeTop: screen.safeTop) + config.topBar.marginTop + 14

                HStack {
                    Spacer()
                    DateTimeWidget()
                        .padding(.top, topOffset)
                        .padding(.trailing, 24)
                }

                Spacer()

                // Bottom area: Now Playing widget bottom-left
                HStack {
                    NowPlayingWidget()
                        .padding(.leading, 24)
                        .padding(.bottom, 24)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}
