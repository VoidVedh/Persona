import SwiftUI

/// Halftone dot grid view rendered with Canvas.
public struct Halftone: View {
    public var dotColor: Color
    public var spacing: CGFloat
    public var maxRadius: CGFloat

    public init(
        dotColor: Color = ThemeColors.cyan.opacity(0.3),
        spacing: CGFloat = 12,
        maxRadius: CGFloat = 3.5
    ) {
        self.dotColor = dotColor
        self.spacing = spacing
        self.maxRadius = maxRadius
    }

    public var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            var y: CGFloat = spacing / 2.0
            while y < size.height {
                var x: CGFloat = spacing / 2.0
                let yProg = y / size.height
                while x < size.width {
                    let xProg = x / size.width
                    // Gradient factor from top-left (largest) to bottom-right (smallest)
                    let factor = max(0.1, 1.0 - (xProg * 0.6 + yProg * 0.4))
                    let r = maxRadius * factor
                    let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}
