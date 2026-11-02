import PersonaCore
import SwiftUI

/// Parallelogram with horizontal shear angle (skew).
/// By default `skew = ThemeTokens.skewDegrees` (-12°).
public struct SkewedPill: Shape {
    public var skewDegrees: Double

    public var animatableData: Double {
        get { skewDegrees }
        set { skewDegrees = newValue }
    }

    public init(skewDegrees: Double = ThemeTokens.skewDegrees) {
        self.skewDegrees = skewDegrees
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let radians = skewDegrees * .pi / 180.0
        let offset = CGFloat(tan(abs(radians))) * rect.height

        if skewDegrees <= 0 {
            // Leans right: top edge shifted right, or bottom left shifted left
            // Top: (offset, 0) -> (rect.width, 0)
            // Bottom: (rect.width - offset, rect.height) -> (0, rect.height)
            path.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - offset, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}
