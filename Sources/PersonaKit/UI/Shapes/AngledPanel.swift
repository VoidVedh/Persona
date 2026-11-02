import PersonaCore
import SwiftUI

/// Angled panel shape: rectangle with skewed left edge and chamfered/clipped top-right corner.
public struct AngledPanel: Shape {
    public var cutSize: CGFloat
    public var skewDegrees: Double

    public init(cutSize: CGFloat = 12, skewDegrees: Double = ThemeTokens.skewDegrees) {
        self.cutSize = cutSize
        self.skewDegrees = skewDegrees
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let radians = abs(skewDegrees) * .pi / 180.0
        let xOffset = CGFloat(tan(radians)) * rect.height
        let cut = min(cutSize, min(rect.width * 0.5, rect.height * 0.5))

        // Start top-left
        path.move(to: CGPoint(x: rect.minX + xOffset, y: rect.minY))
        // Top edge to chamfer
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        // Chamfer down-right
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Back to top-left
        path.closeSubpath()

        return path
    }
}
