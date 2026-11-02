import AppKit
import PersonaCore
import SwiftUI

/// Supplies the SwiftUI/AppKit content for each window. Phase 2 ships a placeholder factory used by
/// `--probe windows` (it also proves true transparency, spike S-5); Phase 3 supplies the real UI.
public protocol WindowContentFactory {
    @MainActor func makeBarContent(screen: ScreenModel, config: AppConfig) -> NSView
    @MainActor func makeOverlayContent(screen: ScreenModel, config: AppConfig) -> NSView?
}

/// Solid cyan bar + translucent diagonal stripes: obviously-visible geometry for window probes.
public struct PlaceholderContentFactory: WindowContentFactory {
    public init() {}

    @MainActor
    public func makeBarContent(screen: ScreenModel, config: AppConfig) -> NSView {
        FirstMouseHostingView(rootView: Color(red: 0, green: 0.85, blue: 1).opacity(0.85))
    }

    @MainActor
    public func makeOverlayContent(screen: ScreenModel, config: AppConfig) -> NSView? {
        FirstMouseHostingView(rootView: PlaceholderStripes())
    }
}

public struct PlaceholderStripes: View {
    public init() {}
    public var body: some View {
        Canvas { context, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + 40, y: size.height))
                path.addLine(to: CGPoint(x: x + 40 + size.height * 0.5, y: 0))
                path.addLine(to: CGPoint(x: x + size.height * 0.5, y: 0))
                path.closeSubpath()
                context.fill(path, with: .color(Color(red: 0, green: 0.32, blue: 1).opacity(0.25)))
                x += 120
            }
        }
        .allowsHitTesting(false)
    }
}

/// Owns one `(TopBarPanel, DesktopOverlayWindow)` pair per display and keeps them in sync with the
/// display configuration.
@MainActor
public final class WindowHostManager {
    public final class Entry {
        public let bar: TopBarPanel
        public let overlay: DesktopOverlayWindow
        init(bar: TopBarPanel, overlay: DesktopOverlayWindow) {
            self.bar = bar
            self.overlay = overlay
        }
    }

    public private(set) var config: AppConfig
    public private(set) var entries: [CGDirectDisplayID: Entry] = [:]
    public private(set) var isRunning = false

    private let factory: WindowContentFactory
    private let screenProvider: @MainActor () -> [ScreenModel]
    private var notificationTokens: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var orderFront = true

    public init(
        config: AppConfig,
        factory: WindowContentFactory,
        screenProvider: @escaping @MainActor () -> [ScreenModel] = { ScreenModel.current() }
    ) {
        self.config = config
        self.factory = factory
        self.screenProvider = screenProvider
    }

    /// Entries ordered primary-first (stable), for probes/tests.
    public var orderedEntries: [(id: CGDirectDisplayID, entry: Entry)] {
        let screens = screenProvider()
        let order = Dictionary(uniqueKeysWithValues: screens.enumerated().map { ($0.element.id, $0.offset) })
        return entries.map { (id: $0.key, entry: $0.value) }
            .sorted { (order[$0.id] ?? Int.max) < (order[$1.id] ?? Int.max) }
    }

    public func start(orderFront: Bool = true) {
        guard !isRunning else { return }
        isRunning = true
        self.orderFront = orderFront
        installObservers()
        reconcile()
    }

    /// Removes observers and closes every window. Safe to call repeatedly.
    public func stop() {
        removeObservers()
        for (_, entry) in entries {
            entry.bar.orderOut(nil)
            entry.overlay.orderOut(nil)
            entry.bar.contentView = nil
            entry.overlay.contentView = nil
            entry.bar.close()
            entry.overlay.close()
        }
        entries.removeAll()
        isRunning = false
    }

    public func updateConfig(_ newConfig: AppConfig) {
        config = newConfig
        guard isRunning else { return }
        for (_, entry) in entries {
            entry.overlay.applyMode(newConfig.wallpaper.mode)
        }
        reconcile(forceContentRebuild: true)
    }

    /// Brings the windows in line with the current displays: creates windows for new displays,
    /// repositions/resizes existing ones, and closes windows whose display disappeared.
    public func reconcile(forceContentRebuild: Bool = false) {
        guard isRunning else { return }
        let screens = screenProvider()
        let liveIDs = Set(screens.map(\.id))

        for id in entries.keys where !liveIDs.contains(id) {
            if let entry = entries.removeValue(forKey: id) {
                entry.bar.orderOut(nil)
                entry.overlay.orderOut(nil)
                entry.bar.close()
                entry.overlay.close()
            }
        }

        for screen in screens {
            if let entry = entries[screen.id] {
                let changed = entry.bar.screenModel != screen
                entry.bar.reposition(for: screen, config: config.topBar)
                entry.overlay.reposition(for: screen, mode: config.wallpaper.mode)
                if changed || forceContentRebuild {
                    entry.bar.setContent(factory.makeBarContent(screen: screen, config: config))
                    rebuildOverlayContent(entry.overlay, screen: screen)
                }
            } else {
                let bar = TopBarPanel(
                    screen: screen,
                    config: config.topBar,
                    content: factory.makeBarContent(screen: screen, config: config)
                )
                let overlay = DesktopOverlayWindow(screen: screen, mode: config.wallpaper.mode, content: nil)
                rebuildOverlayContent(overlay, screen: screen)
                entries[screen.id] = Entry(bar: bar, overlay: overlay)
            }
        }

        if orderFront { orderAllFront() }
    }

    /// Re-asserts level/order after Space or wake changes (levels can be reset by the system).
    public func reassert() {
        guard isRunning else { return }
        for (_, entry) in entries {
            entry.bar.level = WindowLevels.topBar(for: config.topBar.level)
            entry.overlay.level = WindowLevels.desktopOverlay
        }
        if orderFront { orderAllFront() }
    }

    private func rebuildOverlayContent(_ overlay: DesktopOverlayWindow, screen: ScreenModel) {
        let wantsHUD = !config.hud.primaryScreenOnly || screen.isPrimary
        if wantsHUD, let content = factory.makeOverlayContent(screen: screen, config: config) {
            overlay.setContent(content)
        } else {
            overlay.contentView = NSView(frame: NSRect(origin: .zero, size: overlay.frame.size))
        }
    }

    private func orderAllFront() {
        for (_, entry) in entries {
            entry.overlay.orderFrontRegardless()
            entry.bar.orderFrontRegardless()
        }
    }

    private func installObservers() {
        let defaultCenter = NotificationCenter.default
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        let screens = defaultCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
        let wake = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile(); self?.reassert() }
        }
        let space = workspaceCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reassert() }
        }
        notificationTokens = [(defaultCenter, screens), (workspaceCenter, wake), (workspaceCenter, space)]
    }

    private func removeObservers() {
        for item in notificationTokens { item.center.removeObserver(item.token) }
        notificationTokens.removeAll()
    }
}
