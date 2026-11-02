import CoreGraphics
import Foundation

/// Conversion between the two global coordinate systems used by the app.
///
/// - AppKit (`NSScreen`, `NSWindow`): origin at the **bottom-left of the primary display**, y grows up.
/// - AX / CoreGraphics window lists: origin at the **top-left of the primary display**, y grows down.
///
/// The transform `y' = H - (y + h)` (with `H` = height of the primary display) is an involution, so the
/// same math converts in both directions; both names exist so call sites read correctly.
public enum CoordinateSpace {
    /// Converts an AppKit rect (bottom-left origin) into AX space (top-left origin).
    public static func toAX(_ nsRect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: nsRect.origin.x,
            y: primaryHeight - (nsRect.origin.y + nsRect.size.height),
            width: nsRect.size.width,
            height: nsRect.size.height
        )
    }

    /// Converts an AX rect (top-left origin) into AppKit space (bottom-left origin).
    public static func toAppKit(_ axRect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: axRect.origin.x,
            y: primaryHeight - (axRect.origin.y + axRect.size.height),
            width: axRect.size.width,
            height: axRect.size.height
        )
    }

    /// Converts a point between the two spaces (symmetric).
    public static func flip(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
