import PersonaCore
import SwiftUI

/// Chevron / arrow-ended badge shape.
public struct ChevronBadge: Shape {
    public var arrowWidth: CGFloat

    public init(arrowWidth: CGFloat = 10) {
        self.arrowWidth = arrowWidth
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let aw = min(arrowWidth, rect.width * 0.3)
        let midY = rect.midY

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - aw, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX - aw, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + aw, y: midY))
        path.closeSubpath()

        return path
    }
}
