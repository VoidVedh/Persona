import CoreGraphics
import Foundation

/// Horizontal split of the bar content around a camera notch.
public struct ClusterSplit: Equatable {
    /// Width available to the left cluster (bar.minX .. notch left edge).
    public let leftWidth: CGFloat
    /// Width available to the right cluster (notch right edge .. bar.maxX).
    public let rightWidth: CGFloat
    /// Width of the dead zone between the clusters (the notch itself).
    public let gap: CGFloat

    public init(leftWidth: CGFloat, rightWidth: CGFloat, gap: CGFloat) {
        self.leftWidth = leftWidth
        self.rightWidth = rightWidth
        self.gap = gap
    }
}

/// Pure geometry for the Persona windows. All rects are AppKit-space (bottom-left origin, y up).
public enum WindowGeometry {
    /// Bar height: the configured height, but never shorter than the notch's safe-area inset.
    public static func barHeight(configHeight: CGFloat, safeTop: CGFloat) -> CGFloat {
        max(configHeight, safeTop)
    }

    /// Frame of the top bar for a screen (§8.1): inset by `marginSide` horizontally and
    /// `marginTop` from the top edge of the full screen frame.
    public static func barFrame(screenFrame: CGRect, safeTop: CGFloat, config: TopBarConfig) -> CGRect {
        let height = barHeight(configHeight: config.height, safeTop: safeTop)
        let width = max(0, screenFrame.width - 2 * config.marginSide)
        return CGRect(
            x: screenFrame.minX + config.marginSide,
            y: screenFrame.maxY - config.marginTop - height,
            width: width,
            height: height
        ).integral
    }

    /// The desktop overlay always covers the full screen frame.
    public static func overlayFrame(screenFrame: CGRect) -> CGRect {
        screenFrame
    }

    /// Splits the bar into left/right clusters around the notch using the
    /// `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` rects (screen coordinates).
    /// Returns `nil` on screens without a notch (either area missing).
    public static func clusterSplit(barFrame: CGRect, auxLeft: CGRect?, auxRight: CGRect?) -> ClusterSplit? {
        guard let left = auxLeft, let right = auxRight else { return nil }
        let leftWidth = max(0, min(left.maxX, barFrame.maxX) - barFrame.minX)
        let rightWidth = max(0, barFrame.maxX - max(right.minX, barFrame.minX))
        let gap = max(0, barFrame.width - leftWidth - rightWidth)
        return ClusterSplit(leftWidth: leftWidth, rightWidth: rightWidth, gap: gap)
    }

    /// Top edge (AppKit y) below which tiled windows/HUD widgets may be placed: the bar's bottom edge.
    public static func reservedTopEdge(barFrame: CGRect) -> CGFloat {
        barFrame.minY
    }
}
