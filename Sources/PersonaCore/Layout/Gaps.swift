import CoreGraphics
import Foundation

public typealias WindowID = UInt32

/// Inset produced by the top bar at the top of a display.
public struct BarInset: Equatable, Codable {
    public var marginTop: CGFloat
    public var height: CGFloat

    public init(marginTop: CGFloat = 6, height: CGFloat = 38) {
        self.marginTop = marginTop
        self.height = height
    }

    /// Total vertical deadzone at the top of the screen (in points).
    public var totalTop: CGFloat {
        marginTop + height
    }
}

/// Gaps configuration around tiled windows.
public struct Gaps: Equatable, Codable {
    public var outer: CGFloat
    public var inner: CGFloat

    public init(outer: CGFloat = 8, inner: CGFloat = 8) {
        self.outer = outer
        self.inner = inner
    }
}
