import AppKit
import SwiftUI

/// Base class for Persona's non-activating floating panels.
open class PersonaPanel: NSPanel {
    private let allowsKey: Bool

    public init(contentRect: NSRect, allowsKey: Bool = false, extraStyle: NSWindow.StyleMask = []) {
        self.allowsKey = allowsKey
        var mask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        mask.formUnion(extraStyle)
        super.init(
            contentRect: contentRect,
            styleMask: mask,
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        isMovable = false
        isMovableByWindowBackground = false
        becomesKeyOnlyIfNeeded = !allowsKey
        isExcludedFromWindowsMenu = true
    }

    open override var canBecomeKey: Bool { allowsKey }
    open override var canBecomeMain: Bool { false }

    /// AppKit otherwise pushes panels below the menu bar / notch; we want the exact requested frame.
    open override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// `NSHostingView` that accepts the click that would otherwise only "activate" the panel, so bar
/// buttons respond on the first click even though the panel never becomes key.
public final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    public required init(rootView: Content) {
        super.init(rootView: rootView)
        configure()
    }

    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    private func configure() {
        // The panel/window frame is owned by AppKit (WindowHostManager); never let SwiftUI resize it.
        sizingOptions = []
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        autoresizingMask = [.width, .height]
    }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
