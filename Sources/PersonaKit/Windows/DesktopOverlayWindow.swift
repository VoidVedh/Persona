import AppKit
import PersonaCore

/// Full-screen, click-through window that hosts the procedural wallpaper + HUD widgets.
///
/// `ignoresMouseEvents` is **locked to true**: the setter is a no-op, so no code path (or later
/// refactor) can turn this window into something that traps desktop clicks.
public final class DesktopOverlayWindow: NSWindow {
    public static let collectionBehaviorValue: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .ignoresCycle
    ]

    public private(set) var screenModel: ScreenModel
    public private(set) var wallpaperMode: WallpaperMode

    public init(screen: ScreenModel, mode: WallpaperMode, content: NSView?) {
        self.screenModel = screen
        self.wallpaperMode = mode
        super.init(
            contentRect: WindowGeometry.overlayFrame(screenFrame: screen.frame),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        level = WindowLevels.desktopOverlay
        collectionBehavior = DesktopOverlayWindow.collectionBehaviorValue
        hasShadow = false
        sharingType = .none
        isExcludedFromWindowsMenu = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isMovable = false
        title = "Persona Desktop Overlay"
        applyMode(mode)
        if let content { setContent(content) }
        super.ignoresMouseEvents = true
    }

    /// Always `true`; assignments are ignored (see type docs).
    public override var ignoresMouseEvents: Bool {
        get { true }
        set { super.ignoresMouseEvents = true }
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    public func setContent(_ view: NSView) {
        view.frame = NSRect(origin: .zero, size: frame.size)
        view.autoresizingMask = [.width, .height]
        contentView = view
    }

    /// Opaque midnight only when we draw the wallpaper ourselves; otherwise fully transparent.
    public func applyMode(_ mode: WallpaperMode) {
        wallpaperMode = mode
        let opaque = (mode == .overlay)
        isOpaque = opaque
        backgroundColor = opaque ? NSColor(srgbRed: 10 / 255, green: 25 / 255, blue: 47 / 255, alpha: 1) : .clear
    }

    public func reposition(for screen: ScreenModel, mode: WallpaperMode? = nil) {
        screenModel = screen
        if let mode { applyMode(mode) }
        level = WindowLevels.desktopOverlay
        setFrame(WindowGeometry.overlayFrame(screenFrame: screen.frame), display: true)
    }
}
