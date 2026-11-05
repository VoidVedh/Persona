import AppKit
import CoreGraphics
import Foundation
import PersonaCore
import SwiftUI

/// Transparent, click-through overlay window hosting the glowing cyan border ring
/// that follows the focused active application window.
public final class BorderOverlayWindow: NSWindow {
    public private(set) var screenModel: ScreenModel
    private let shapeLayer = CAShapeLayer()
    private var currentPathRect: CGRect?

    /// Hard-lock click-through: the border overlay must never intercept mouse events.
    public override var ignoresMouseEvents: Bool {
        get { true }
        set { super.ignoresMouseEvents = true }
    }

    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    public init(screen: ScreenModel) {
        self.screenModel = screen

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // Enforce Guardrail 4: click-through, transparent, no shadow
        super.ignoresMouseEvents = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.animationBehavior = .none
        self.level = WindowLevels.border
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .transient]
        self.sharingType = .none
        self.isExcludedFromWindowsMenu = true

        setupLayer()
    }

    private func setupLayer() {
        let view = NSView(frame: NSRect(origin: .zero, size: screenModel.frame.size))
        view.wantsLayer = true
        guard let layer = view.layer else { return }

        let cyanColor = NSColor(
            red: 0x00 / 255.0,
            green: 0xd8 / 255.0,
            blue: 0xff / 255.0,
            alpha: 1.0
        ).cgColor

        shapeLayer.frame = layer.bounds
        shapeLayer.strokeColor = cyanColor
        shapeLayer.fillColor = nil
        shapeLayer.lineWidth = 3.0
        shapeLayer.shadowColor = cyanColor
        shapeLayer.shadowRadius = 10.0
        shapeLayer.shadowOpacity = 0.85
        shapeLayer.shadowOffset = .zero

        layer.addSublayer(shapeLayer)
        self.contentView = view
    }

    public func reposition(for screen: ScreenModel) {
        self.screenModel = screen
        self.setFrame(screen.frame, display: true)
        if let view = self.contentView {
            view.frame = NSRect(origin: .zero, size: screen.frame.size)
            shapeLayer.frame = view.bounds
        }
    }

    /// Updates the position and size of the glowing ring in AppKit coordinates for this screen.
    public func updateRing(
        rectAppKit: CGRect?,
        cornerRadius: CGFloat = 16.0,
        borderWidth: CGFloat = 3.0,
        pulse: Bool = true,
        animated: Bool = true
    ) {
        guard let target = rectAppKit else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shapeLayer.path = nil
            shapeLayer.shadowPath = nil
            shapeLayer.removeAnimation(forKey: "borderPulse")
            currentPathRect = nil
            CATransaction.commit()
            return
        }

        // Convert target rect from screen absolute to window local coordinates
        let localRect = CGRect(
            x: target.minX - screenModel.frame.minX,
            y: target.minY - screenModel.frame.minY,
            width: target.width,
            height: target.height
        )

        let newPath = CGPath(
            roundedRect: localRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )

        if animated, let oldRect = currentPathRect, oldRect != localRect {
            let anim = CABasicAnimation(keyPath: "path")
            anim.duration = 0.09
            anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
            shapeLayer.add(anim, forKey: "pathGlide")
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.lineWidth = borderWidth
        shapeLayer.path = newPath
        shapeLayer.shadowPath = newPath
        currentPathRect = localRect

        let allowAnim = pulse && ProcessInfo.processInfo.environment["PERSONA_HUD_ANIMATION"] != "0"
        if allowAnim {
            if shapeLayer.animation(forKey: "borderPulse") == nil {
                let pulseAnim = CABasicAnimation(keyPath: "shadowOpacity")
                pulseAnim.fromValue = 0.55
                pulseAnim.toValue = 0.95
                pulseAnim.duration = 2.4
                pulseAnim.autoreverses = true
                pulseAnim.repeatCount = .infinity
                pulseAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                shapeLayer.add(pulseAnim, forKey: "borderPulse")
            }
        } else {
            shapeLayer.removeAnimation(forKey: "borderPulse")
        }
        CATransaction.commit()
    }
}

/// Offscreen SwiftUI view for rendering the active-window border preview (`--probe render border`).
/// Uses zero Swift macros for CommandLineTools compatibility.
public struct BorderPreviewView: View {
    public let width: CGFloat
    public let height: CGFloat
    public let borderWidth: CGFloat
    public let cornerRadius: CGFloat

    public init(
        width: CGFloat = 600,
        height: CGFloat = 400,
        borderWidth: CGFloat = 3.0,
        cornerRadius: CGFloat = 16.0
    ) {
        self.width = width
        self.height = height
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        ZStack {
            ThemeColors.abyss.ignoresSafeArea()

            // Simulated focused window surface
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ThemeColors.midnight.opacity(0.92))
                .frame(width: width - 80, height: height - 80)
                .overlay(
                    VStack(spacing: 8) {
                        Text("ACTIVE WINDOW TARGET")
                            .font(Fonts.display(20))
                            .foregroundColor(ThemeColors.cyan)
                        Text("GLOWING P3R CYAN BORDER OVERLAY")
                            .font(Fonts.body(13))
                            .foregroundColor(ThemeColors.ice.opacity(0.85))
                    }
                )

            // Outer glowing ring
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ThemeColors.cyan, lineWidth: borderWidth)
                .shadow(color: ThemeColors.cyan.opacity(0.9), radius: 10, x: 0, y: 0)
                .shadow(color: ThemeColors.cyan.opacity(0.5), radius: 4, x: 0, y: 0)
                .frame(width: width - 80 + borderWidth, height: height - 80 + borderWidth)
        }
        .frame(width: width, height: height)
    }
}
