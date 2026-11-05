import AppKit
import CoreGraphics
import Foundation
import PersonaCore
import SwiftUI

/// Transparent, click-through overlay window hosting the P3R 5-layer glowing border + corner brackets (§6.8)
/// that follows the focused active application window.
public final class BorderOverlayWindow: NSWindow {
    public private(set) var screenModel: ScreenModel

    private let groupLayer = CALayer()
    public let glowOuterLayer = CAShapeLayer()
    public let glowInnerLayer = CAShapeLayer()
    public let frameShapeLayer = CAShapeLayer()
    public let bracketsLayer = CAShapeLayer()
    public let ticksLayer = CAShapeLayer()

    public var borderSublayers: [CAShapeLayer] {
        [glowOuterLayer, glowInnerLayer, frameShapeLayer, bracketsLayer, ticksLayer]
    }

    private var currentPathRect: CGRect?
    private var currentStyle: BorderStyle?
    private var currentBracketLength: CGFloat?
    public private(set) var updateCount: Int = 0

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

        setupLayers()
    }

    private static var cyanCG: CGColor {
        NSColor(red: 0x00 / 255.0, green: 0xd8 / 255.0, blue: 0xff / 255.0, alpha: 1.0).cgColor
    }

    private static var cyanFrameCG: CGColor {
        NSColor(red: 0x00 / 255.0, green: 0xd8 / 255.0, blue: 0xff / 255.0, alpha: 0.55).cgColor
    }

    private static var royalCG: CGColor {
        NSColor(red: 0x00 / 255.0, green: 0x51 / 255.0, blue: 0xff / 255.0, alpha: 1.0).cgColor
    }

    private static var whiteCG: CGColor {
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0).cgColor
    }

    private static var whiteStrokeCG: CGColor {
        NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.90).cgColor
    }

    private func setupLayers() {
        let view = NSView(frame: NSRect(origin: .zero, size: screenModel.frame.size))
        view.wantsLayer = true
        guard let rootLayer = view.layer else { return }

        let bounds = rootLayer.bounds
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0

        groupLayer.frame = bounds
        groupLayer.shouldRasterize = true
        groupLayer.rasterizationScale = scale

        // 1. glowOuter (#0051ff, radius 18, opacity 0.45)
        glowOuterLayer.name = "glowOuter"
        glowOuterLayer.frame = bounds
        glowOuterLayer.fillColor = nil
        glowOuterLayer.strokeColor = nil
        glowOuterLayer.shadowColor = Self.royalCG
        glowOuterLayer.shadowRadius = 18.0
        glowOuterLayer.shadowOpacity = 0.45
        glowOuterLayer.shadowOffset = .zero

        // 2. glowInner (#00d8ff, radius 6, opacity 0.90)
        glowInnerLayer.name = "glowInner"
        glowInnerLayer.frame = bounds
        glowInnerLayer.fillColor = nil
        glowInnerLayer.strokeColor = nil
        glowInnerLayer.shadowColor = Self.cyanCG
        glowInnerLayer.shadowRadius = 6.0
        glowInnerLayer.shadowOpacity = 0.90
        glowInnerLayer.shadowOffset = .zero

        // 3. frame (stroke #00d8ff @ 0.55, lineWidth 2)
        frameShapeLayer.name = "frame"
        frameShapeLayer.frame = bounds
        frameShapeLayer.fillColor = nil
        frameShapeLayer.strokeColor = Self.cyanFrameCG
        frameShapeLayer.lineWidth = 2.0

        // 4. brackets (4 chamfered L-brackets, fill #00d8ff, 1px white @ 0.9 stroke)
        bracketsLayer.name = "brackets"
        bracketsLayer.frame = bounds
        bracketsLayer.fillColor = Self.cyanCG
        bracketsLayer.strokeColor = Self.whiteStrokeCG
        bracketsLayer.lineWidth = 1.0

        // 5. ticks (4 x 3x3 white squares at outer corners)
        ticksLayer.name = "ticks"
        ticksLayer.frame = bounds
        ticksLayer.fillColor = Self.whiteCG
        ticksLayer.strokeColor = nil

        groupLayer.addSublayer(glowOuterLayer)
        groupLayer.addSublayer(glowInnerLayer)
        groupLayer.addSublayer(frameShapeLayer)
        groupLayer.addSublayer(bracketsLayer)
        groupLayer.addSublayer(ticksLayer)

        rootLayer.addSublayer(groupLayer)
        self.contentView = view
    }

    public func reposition(for screen: ScreenModel) {
        self.screenModel = screen
        self.setFrame(screen.frame, display: true)
        if let view = self.contentView {
            view.frame = NSRect(origin: .zero, size: screen.frame.size)
            let b = view.bounds
            groupLayer.frame = b
            for sub in borderSublayers {
                sub.frame = b
            }
        }
    }

    /// Builds the 4 chamfered L-brackets path for `rect` (§6.8):
    /// `(0,0) -> (L,0) -> (L-4,T) -> (T,T) -> (T,L-4) -> (0,L) -> close` mirrored across all 4 corners.
    public static func makeBracketsPath(
        for rect: CGRect,
        bracketLength: CGFloat = 28.0,
        thickness: CGFloat = 4.0
    ) -> CGPath {
        let L = min(48.0, max(16.0, bracketLength))
        let T = max(3.0, thickness)
        let tip: CGFloat = 4.0

        let baseCorner = CGMutablePath()
        baseCorner.move(to: CGPoint(x: 0, y: 0))
        baseCorner.addLine(to: CGPoint(x: L, y: 0))
        baseCorner.addLine(to: CGPoint(x: L - tip, y: T))
        baseCorner.addLine(to: CGPoint(x: T, y: T))
        baseCorner.addLine(to: CGPoint(x: T, y: L - tip))
        baseCorner.addLine(to: CGPoint(x: 0, y: L))
        baseCorner.closeSubpath()

        let combined = CGMutablePath()
        let outRect = rect.insetBy(dx: -2.0, dy: -2.0)

        // Bottom-left corner: (+1, +1) from (minX, minY)
        let bl = CGAffineTransform(translationX: outRect.minX, y: outRect.minY)
        combined.addPath(baseCorner, transform: bl)

        // Bottom-right corner: (-1, +1) from (maxX, minY)
        let br = CGAffineTransform(translationX: outRect.maxX, y: outRect.minY)
            .scaledBy(x: -1, y: 1)
        combined.addPath(baseCorner, transform: br)

        // Top-left corner: (+1, -1) from (minX, maxY)
        let tl = CGAffineTransform(translationX: outRect.minX, y: outRect.maxY)
            .scaledBy(x: 1, y: -1)
        combined.addPath(baseCorner, transform: tl)

        // Top-right corner: (-1, -1) from (maxX, maxY)
        let tr = CGAffineTransform(translationX: outRect.maxX, y: outRect.maxY)
            .scaledBy(x: -1, y: -1)
        combined.addPath(baseCorner, transform: tr)

        return combined
    }

    /// Builds the 4 outer corner 3x3 tick squares path for `rect` (§6.8).
    public static func makeTicksPath(for rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let outRect = rect.insetBy(dx: -5.0, dy: -5.0)
        let s: CGFloat = 3.5
        path.addRect(CGRect(x: outRect.minX, y: outRect.minY, width: s, height: s))
        path.addRect(CGRect(x: outRect.maxX - s, y: outRect.minY, width: s, height: s))
        path.addRect(CGRect(x: outRect.minX, y: outRect.maxY - s, width: s, height: s))
        path.addRect(CGRect(x: outRect.maxX - s, y: outRect.maxY - s, width: s, height: s))
        return path
    }

    /// Updates the position and size of the glowing P3R border ring in AppKit coordinates for this screen.
    public func updateRing(
        rectAppKit: CGRect?,
        cornerRadius: CGFloat = 16.0,
        borderWidth: CGFloat = 3.0,
        style: BorderStyle = .p3r,
        bracketLength: CGFloat = 28.0,
        pulse: Bool = true,
        animated: Bool = true
    ) {
        let clampedBracket = min(48.0, max(16.0, bracketLength))

        guard let target = rectAppKit else {
            guard currentPathRect != nil else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for sub in borderSublayers {
                sub.path = nil
                sub.shadowPath = nil
                sub.removeAllAnimations()
            }
            currentPathRect = nil
            currentStyle = nil
            currentBracketLength = nil
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

        // Early-out if rect, style, and bracketLength are unchanged (prevents layer rasterization churn)
        if currentPathRect == localRect && currentStyle == style && currentBracketLength == clampedBracket {
            return
        }

        updateCount += 1

        let maxRadius = max(0, min(cornerRadius, min(localRect.width, localRect.height) * 0.45))
        let ringPath = CGPath(
            roundedRect: localRect,
            cornerWidth: maxRadius,
            cornerHeight: maxRadius,
            transform: nil
        )
        let strokedShadowPath = ringPath.copy(
            strokingWithWidth: max(2.0, borderWidth),
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 10
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        glowOuterLayer.path = ringPath
        glowOuterLayer.shadowPath = strokedShadowPath

        glowInnerLayer.path = ringPath
        glowInnerLayer.shadowPath = strokedShadowPath

        frameShapeLayer.path = ringPath
        frameShapeLayer.lineWidth = (style == .plain) ? borderWidth : 2.0
        frameShapeLayer.strokeColor = (style == .plain) ? Self.cyanCG : Self.cyanFrameCG

        if style == .p3r {
            bracketsLayer.path = Self.makeBracketsPath(
                for: localRect,
                bracketLength: clampedBracket,
                thickness: max(3.5, borderWidth)
            )
            ticksLayer.path = Self.makeTicksPath(for: localRect)
        } else {
            bracketsLayer.path = nil
            ticksLayer.path = nil
        }

        currentPathRect = localRect
        currentStyle = style
        currentBracketLength = clampedBracket

        let allowAnim = pulse && ProcessInfo.processInfo.environment["PERSONA_HUD_ANIMATION"] != "0"
        if allowAnim {
            for glow in [glowOuterLayer, glowInnerLayer] where glow.animation(forKey: "borderPulse") == nil {
                let pulseAnim = CABasicAnimation(keyPath: "opacity")
                pulseAnim.fromValue = 0.75
                pulseAnim.toValue = 1.0
                pulseAnim.duration = 2.4
                pulseAnim.autoreverses = true
                pulseAnim.repeatCount = .infinity
                pulseAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                glow.add(pulseAnim, forKey: "borderPulse")
            }
        } else {
            glowOuterLayer.removeAnimation(forKey: "borderPulse")
            glowInnerLayer.removeAnimation(forKey: "borderPulse")
        }

        CATransaction.commit()
    }

    /// Renders the real `BorderOverlayWindow` CoreAnimation layers over a synthetic dark window for `--probe render border` (§6.8, §12.1).
    public static func renderPreviewCGImage(
        width: CGFloat = 800,
        height: CGFloat = 520,
        scale: CGFloat = 2.0
    ) -> CGImage? {
        let screen = ScreenModel(
            id: 1,
            uuid: "border-preview",
            frame: CGRect(x: 0, y: 0, width: width, height: height)
        )
        let borderWin = BorderOverlayWindow(screen: screen)
        defer { borderWin.close() }

        let insetX: CGFloat = 68
        let insetY: CGFloat = 56
        let targetWinFrameAX = CGRect(
            x: insetX,
            y: insetY,
            width: width - insetX * 2,
            height: height - insetY * 2
        )
        let borderWidth: CGFloat = 3.0
        let cornerRadius: CGFloat = 14.0
        let ringRect = BorderGeometry.ringRectAppKit(
            windowFrameAX: targetWinFrameAX,
            borderWidth: borderWidth,
            primaryScreenHeight: height
        )

        borderWin.updateRing(
            rectAppKit: ringRect,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            style: .p3r,
            bracketLength: 28.0,
            pulse: false,
            animated: false
        )

        let pxW = Int(width * scale)
        let pxH = Int(height * scale)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: pxW,
                  height: pxH,
                  bitsPerComponent: 8,
                  bytesPerRow: pxW * 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            return nil
        }

        ctx.scaleBy(x: scale, y: scale)

        // 0. Dark abyss desktop backdrop (inset by 12pt so corners remain transparent while glow/ticks have dark contrast)
        let backdropRect = CGRect(x: 12, y: 12, width: width - 24, height: height - 24)
        let backdropPath = CGPath(roundedRect: backdropRect, cornerWidth: 18, cornerHeight: 18, transform: nil)
        ctx.saveGState()
        ctx.addPath(backdropPath)
        ctx.setFillColor(NSColor(red: 0x05 / 255.0, green: 0x0c / 255.0, blue: 0x1a / 255.0, alpha: 1.0).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // 1. Draw the two-tone outer/inner glow outside the synthetic window
        let ringPath = CGPath(
            roundedRect: ringRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 18.0, color: Self.royalCG)
        ctx.setStrokeColor(NSColor(red: 0, green: 0x51 / 255.0, blue: 1.0, alpha: 0.65).cgColor)
        ctx.setLineWidth(4.0)
        ctx.addPath(ringPath)
        ctx.strokePath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 7.0, color: Self.cyanCG)
        ctx.setStrokeColor(NSColor(red: 0, green: 0xd8 / 255.0, blue: 1.0, alpha: 0.85).cgColor)
        ctx.setLineWidth(2.5)
        ctx.addPath(ringPath)
        ctx.strokePath()
        ctx.restoreGState()

        // 2. Draw the synthetic dark window strictly INSIDE targetWinFrameAppKit (so the border ring sits outside its edge)
        let winRectAppKit = CoordinateSpace.toAppKit(targetWinFrameAX, primaryHeight: height)
        let winPath = CGPath(
            roundedRect: winRectAppKit,
            cornerWidth: max(0, cornerRadius - 2),
            cornerHeight: max(0, cornerRadius - 2),
            transform: nil
        )
        ctx.saveGState()
        ctx.addPath(winPath)
        ctx.clip()

        // Window body fill (#0a192f midnight)
        ctx.setFillColor(NSColor(red: 0x0a / 255.0, green: 0x19 / 255.0, blue: 0x2f / 255.0, alpha: 0.97).cgColor)
        ctx.fill(winRectAppKit)

        // Window titlebar (#050c1a abyss)
        let titleBarH: CGFloat = 32
        let titleBarRect = CGRect(
            x: winRectAppKit.minX,
            y: winRectAppKit.maxY - titleBarH,
            width: winRectAppKit.width,
            height: titleBarH
        )
        ctx.setFillColor(NSColor(red: 0x05 / 255.0, green: 0x0c / 255.0, blue: 0x1a / 255.0, alpha: 1.0).cgColor)
        ctx.fill(titleBarRect)

        // Subtle cyan divider under titlebar
        ctx.setFillColor(NSColor(red: 0x00 / 255.0, green: 0xd8 / 255.0, blue: 0xff / 255.0, alpha: 0.35).cgColor)
        ctx.fill(CGRect(x: winRectAppKit.minX, y: winRectAppKit.maxY - titleBarH - 1, width: winRectAppKit.width, height: 1))
        ctx.restoreGState()

        // 3. Render the real BorderOverlayWindow CALayer hierarchy (frame, 4 chamfered L-brackets, 4 white corner ticks)
        if let rootLayer = borderWin.contentView?.layer {
            borderWin.groupLayer.shouldRasterize = false
            rootLayer.render(in: ctx)
            borderWin.groupLayer.shouldRasterize = true
        }

        return ctx.makeImage()
    }
}
