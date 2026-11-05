import AppKit
import Foundation
import PersonaCore

/// Dual-engine `WindowContentFactory` (ADR-V2-9): serves hardware-accelerated `WebSurfaceView`
/// surfaces when `config.ui.engine == .web` and `WebTransparencyCheck.passes()`, or automatically
/// falls back to `PersonaContentFactory` (SwiftUI).
public struct WebContentFactory: WindowContentFactory {
    public var onQuit: (() -> Void)?

    public init(onQuit: (() -> Void)? = nil) {
        self.onQuit = onQuit
    }

    @MainActor
    public func makeBarContent(screen: ScreenModel, config: AppConfig) -> NSView {
        if config.ui.engine == .swiftui || !WebTransparencyCheck.passes() {
            if config.ui.engine == .web {
                fputs("warning: WebTransparencyCheck failed; falling back to SwiftUI engine.\n", stderr)
                AppState.shared.usingSwiftUIFallback = true
            }
            return PersonaContentFactory(onQuit: onQuit).makeBarContent(screen: screen, config: config)
        }

        AppState.shared.usingSwiftUIFallback = false
        WebStatePublisher.shared.start(config: config)

        let quitCallback = onQuit
        let web = WebSurfaceView(
            surface: .topbar,
            interactive: true,
            debug: config.ui.debugInspector || ProcessInfo.processInfo.environment["PERSONA_WEBUI_DEBUG"] == "1"
        ) { intent in
            switch intent {
            case .exit:
                if let q = quitCallback {
                    q()
                } else {
                    CommandRouter.shared.send(.exitPersona)
                }
            case .switchSpace(let n):
                CommandRouter.shared.send(.switchSpace(n))
            default:
                break
            }
        }
        WebStatePublisher.shared.registerTopBar(web, screen: screen)
        web.loadSurface()
        return web
    }

    @MainActor
    public func makeOverlayContent(screen: ScreenModel, config: AppConfig) -> NSView? {
        if config.ui.engine == .swiftui || !WebTransparencyCheck.passes() {
            return PersonaContentFactory(onQuit: onQuit).makeOverlayContent(screen: screen, config: config)
        }

        WebStatePublisher.shared.start(config: config)
        let web = WebSurfaceView(
            surface: .hud,
            interactive: false,
            debug: config.ui.debugInspector || ProcessInfo.processInfo.environment["PERSONA_WEBUI_DEBUG"] == "1"
        )
        WebStatePublisher.shared.registerHUD(web, screen: screen)
        web.loadSurface()
        return web
    }
}

