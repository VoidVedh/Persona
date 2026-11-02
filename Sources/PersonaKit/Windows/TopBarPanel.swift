import AppKit
import PersonaCore

/// The Waybar-style bar pinned to the top of a display.
///
/// - Style mask `[.borderless, .nonactivatingPanel]`: clicking widgets never steals focus from the
///   user's frontmost app.
/// - Level `.statusBar` (configurable), clear/non-opaque, no shadow, never hides on deactivate.
/// - Joins all Spaces, stays out of Cmd+Tab/window cycling, remains visible over full-screen apps.
public final class TopBarPanel: PersonaPanel {
    public static let collectionBehaviorValue: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle
    ]

    public private(set) var screenModel: ScreenModel
    public private(set) var barConfig: TopBarConfig

    public init(screen: ScreenModel, config: TopBarConfig, content: NSView) {
        self.screenModel = screen
        self.barConfig = config
        let frame = TopBarPanel.frame(for: screen, config: config)
        super.init(contentRect: frame, allowsKey: false)
        level = WindowLevels.topBar(for: config.level)
        collectionBehavior = TopBarPanel.collectionBehaviorValue
        ignoresMouseEvents = false
        title = "Persona Top Bar"
        setContent(content)
        setFrame(frame, display: false)
    }

    /// Frame for a screen in AppKit coordinates (notch-aware height, §8.1).
    public static func frame(for screen: ScreenModel, config: TopBarConfig) -> NSRect {
        WindowGeometry.barFrame(screenFrame: screen.frame, safeTop: screen.safeTop, config: config)
    }

    /// Notch-aware split of the bar for the current screen (nil without a notch).
    public var clusterSplit: ClusterSplit? {
        WindowGeometry.clusterSplit(barFrame: frame, auxLeft: screenModel.auxLeft, auxRight: screenModel.auxRight)
    }

    public func setContent(_ view: NSView) {
        view.frame = NSRect(origin: .zero, size: frame.size)
        view.autoresizingMask = [.width, .height]
        contentView = view
    }

    /// Re-derives frame + level for a changed screen or config.
    public func reposition(for screen: ScreenModel, config: TopBarConfig? = nil) {
        screenModel = screen
        if let config { barConfig = config }
        level = WindowLevels.topBar(for: barConfig.level)
        setFrame(TopBarPanel.frame(for: screen, config: barConfig), display: true)
    }
}
