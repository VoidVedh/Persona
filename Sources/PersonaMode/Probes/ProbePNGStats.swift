import AppKit
import CoreGraphics
import Foundation
import ImageIO

/// Inspects a rendered PNG file and emits pixel coverage, bounding box, and P3R palette shares (§12.1, §12.4).
@MainActor
public enum ProbePNGStats: Probe {
    public static func run(args: [String]) -> Int32 {
        guard let path = args.first else {
            fputs("Usage: --probe png-stats <file.png> [--out out.json]\n", stderr)
            return 1
        }

        let url = URL(fileURLWithPath: path)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            fputs("Error: could not read PNG at \(path)\n", stderr)
            return 1
        }

        let w = cgImage.width
        let h = cgImage.height
        guard w > 0, h > 0 else {
            fputs("Error: empty image dimensions\n", stderr)
            return 1
        }

        let bytesPerPixel = 4
        let bytesPerRow = w * bytesPerPixel
        var raw = [UInt8](repeating: 0, count: h * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: &raw,
                  width: w,
                  height: h,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
              ) else {
            fputs("Error: failed to create pixel context\n", stderr)
            return 1
        }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var visibleCount = 0
        var cyanCount = 0
        var whiteCount = 0
        var navyCount = 0
        var minX = w
        var minY = h
        var maxX = -1
        var maxY = -1

        for y in 0..<h {
            let rowOffset = y * bytesPerRow
            for x in 0..<w {
                let idx = rowOffset + x * 4
                let a = Int(raw[idx + 3])
                if a >= 13 { // >= ~5% alpha
                    visibleCount += 1
                    if x < minX { minX = x }
                    if y < minY { minY = y }
                    if x > maxX { maxX = x }
                    if y > maxY { maxY = y }

                    // Unpremultiply RGB for accurate color classification
                    let r = min(255, (Int(raw[idx]) * 255) / max(1, a))
                    let g = min(255, (Int(raw[idx + 1]) * 255) / max(1, a))
                    let b = min(255, (Int(raw[idx + 2]) * 255) / max(1, a))

                    // Cyan (#00d8ff = 0,216,255) or Cyan-Hi (#5ce5ff = 92,229,255) or Dark Hour (#5dffcf = 93,255,207) or Royal/Azure
                    let isCyan = (abs(r - 0) <= 36 && abs(g - 216) <= 36 && abs(b - 255) <= 36) ||
                        (abs(r - 92) <= 36 && abs(g - 229) <= 36 && abs(b - 255) <= 36) ||
                        (abs(r - 93) <= 36 && abs(g - 255) <= 36 && abs(b - 207) <= 36) ||
                        (r <= 60 && g >= 140 && b >= 180)
                    let isWhite = (r >= 220 && g >= 230 && b >= 240)
                    let isNavy = (r <= 36 && g <= 65 && b <= 115)

                    if isWhite {
                        whiteCount += 1
                    } else if isCyan {
                        cyanCount += 1
                    } else if isNavy {
                        navyCount += 1
                    }
                }
            }
        }

        func cornerAlpha(_ cx: Int, _ cy: Int) -> Double {
            let idx = cy * bytesPerRow + cx * 4
            return (Double(raw[idx + 3]) / 255.0 * 100.0 * 100.0).rounded() / 100.0
        }

        let totalPixels = Double(w * h)
        let denom = Double(max(1, visibleCount))
        let alphaCoveragePct = (Double(visibleCount) / totalPixels * 10000.0).rounded() / 100.0
        let cyanPct = (Double(cyanCount) / denom * 10000.0).rounded() / 100.0
        let whitePct = (Double(whiteCount) / denom * 10000.0).rounded() / 100.0
        let navyPct = (Double(navyCount) / denom * 10000.0).rounded() / 100.0

        let bbox: [Int] = visibleCount > 0 ? [minX, minY, maxX, maxY] : [0, 0, 0, 0]
        let corners: [Double] = [
            cornerAlpha(0, 0),
            cornerAlpha(w - 1, 0),
            cornerAlpha(0, h - 1),
            cornerAlpha(w - 1, h - 1),
        ]

        let result: [String: Any] = [
            "alphaCoveragePct": alphaCoveragePct,
            "bbox": bbox,
            "cornerAlphaPct": corners,
            "cyanPct": cyanPct,
            "h": h,
            "navyPct": navyPct,
            "w": w,
            "whitePct": whitePct,
        ]
        return ProbeIO.emit(result, args: args)
    }
}

