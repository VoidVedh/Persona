import AppKit
import PersonaCore
import SwiftUI

/// Production WindowContentFactory providing authentic Persona 3 Reload TopBarView and HUDView.
public struct PersonaContentFactory: WindowContentFactory {
    public var onQuit: (() -> Void)?

    public init(onQuit: (() -> Void)? = nil) {
        self.onQuit = onQuit
    }

    @MainActor
    public func makeBarContent(screen: ScreenModel, config: AppConfig) -> NSView {
        Fonts.register()
        let view = TopBarView(screen: screen, config: config.topBar, onQuit: onQuit)
        return FirstMouseHostingView(rootView: view)
    }

    @MainActor
    public func makeOverlayContent(screen: ScreenModel, config: AppConfig) -> NSView? {
        Fonts.register()
        let view = HUDView(screen: screen, config: config)
        return FirstMouseHostingView(rootView: view)
    }
}
