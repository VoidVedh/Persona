import SwiftUI

/// Regular hexagon stroke ring with optional rotation.
public struct HexRing: Shape {
    public var rotation: Angle

    public init(rotation: Angle = .zero) {
        self.rotation = rotation
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.5
        let rotRad = rotation.radians

        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3.0 + CGFloat(rotRad)
            let pt = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}
