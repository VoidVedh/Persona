import AppKit
import Foundation
import PersonaCore

/// Non-activating borderless floating NSPanel for the Persona 3 Reload App Launcher.
/// Sits at `WindowLevels.launcher` (popUpMenu - 1 = 100) and accepts key focus when summoned.
public final class LauncherPanel: PersonaPanel {
    public static let defaultSize = CGSize(width: 640, height: 472)

    public init(screen: ScreenModel, content: NSView) {
        let frame = Self.centeredFrame(for: screen)
        super.init(contentRect: frame, allowsKey: true)

        self.level = WindowLevels.launcher
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true

        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true

        content.frame = visualEffect.bounds
        content.autoresizingMask = [.width, .height]
        visualEffect.addSubview(content)

        self.contentView = visualEffect
    }

    /// Positions the launcher horizontally centered and at 38% from the top of the target screen.
    public static func centeredFrame(for screen: ScreenModel) -> CGRect {
        let w = defaultSize.width
        let h = defaultSize.height
        let x = screen.frame.minX + (screen.frame.width - w) * 0.5
        let centerYFromTop = screen.frame.height * 0.38
        let y = screen.frame.maxY - centerYFromTop - h * 0.5
        return CGRect(x: x, y: y, width: w, height: h).integral
    }

    public func reposition(for screen: ScreenModel) {
        self.setFrame(Self.centeredFrame(for: screen), display: true)
    }
}
