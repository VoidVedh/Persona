import CoreGraphics
import Foundation

/// Pure geometry for the active-window border overlay ring.
public enum BorderGeometry {
    /// Computes the shape layer path rect for a focused window frame in AX coordinates.
    ///
    /// The rect is outset by `borderWidth / 2` so that centering the stroke path of `borderWidth`
    /// places the stroke entirely outside the window's interior pixels, within the inner gap.
    public static func ringRect(windowFrameAX: CGRect, borderWidth: CGFloat) -> CGRect {
        let half = borderWidth / 2.0
        return windowFrameAX.insetBy(dx: -half, dy: -half)
    }

    /// Clamps the border stroke width to never exceed the available inner gap.
    public static func clampedWidth(width: CGFloat, innerGap: CGFloat) -> CGFloat {
        max(1.0, min(width, innerGap))
    }

    /// Computes the border ring frame in AppKit bottom-left coordinates from an AX top-left window frame.
    public static func ringRectAppKit(
        windowFrameAX: CGRect,
        borderWidth: CGFloat,
        primaryScreenHeight: CGFloat
    ) -> CGRect {
        let axRing = ringRect(windowFrameAX: windowFrameAX, borderWidth: borderWidth)
        return CoordinateSpace.toAppKit(axRing, primaryHeight: primaryScreenHeight)
    }
}
