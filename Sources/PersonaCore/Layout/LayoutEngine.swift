import CoreGraphics
import Foundation

/// Pure window layout engine operating in Quartz AX (top-left) coordinates.
public enum LayoutEngine {
    /// Minimum width allowed for a tiled window.
    public static let minWidth: CGFloat = 100
    /// Minimum height allowed for a tiled window.
    public static let minHeight: CGFloat = 60

    /// Computes window frames in AX coordinates for a given screen and window IDs.
    ///
    /// - Parameters:
    ///   - ids: Window IDs in focus/priority order.
    ///   - screen: Screen frame in AX coordinates (top-left origin).
    ///   - bar: Bar inset at the top of the screen.
    ///   - gaps: Outer and inner spacing.
    ///   - algorithm: Tiling algorithm (`.dwindle` or `.masterStack`).
    ///   - splitRatio: Ratio used for partitioning (e.g. 0.5 for dwindle, 0.55 for masterStack).
    /// - Returns: Dictionary mapping each WindowID to its computed AX frame.
    public static func layout(
        ids: [WindowID],
        screen: CGRect,
        bar: BarInset,
        gaps: Gaps,
        algorithm: TilingAlgorithm = .dwindle,
        splitRatio: CGFloat = 0.5
    ) -> [WindowID: CGRect] {
        guard !ids.isEmpty else { return [:] }

        let topInset = bar.totalTop + gaps.outer
        let usableX = screen.minX + gaps.outer
        let usableY = screen.minY + topInset
        let usableWidth = max(0, screen.width - 2 * gaps.outer)
        let usableHeight = max(0, screen.height - topInset - gaps.outer)

        let usable = CGRect(x: usableX, y: usableY, width: usableWidth, height: usableHeight).integral

        guard ids.count > 1 else {
            return [ids[0]: usable]
        }

        switch algorithm {
        case .dwindle:
            return layoutDwindle(ids: ids, usable: usable, gaps: gaps, splitRatio: splitRatio)
        case .masterStack:
            return layoutMasterStack(ids: ids, usable: usable, gaps: gaps, splitRatio: splitRatio)
        }
    }

    // MARK: - Dwindle Algorithm

    private static func layoutDwindle(
        ids: [WindowID],
        usable: CGRect,
        gaps: Gaps,
        splitRatio: CGFloat
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        var remainingRect = usable
        let ratio = min(0.85, max(0.15, splitRatio))

        for i in 0 ..< (ids.count - 1) {
            let id = ids[i]
            let isVertical = remainingRect.width >= remainingRect.height

            if isVertical {
                let availWidth = remainingRect.width - gaps.inner
                guard availWidth > 0 else {
                    for remId in ids[i...] { result[remId] = remainingRect.integral }
                    return result
                }

                let firstW = floor(availWidth * ratio)
                let secondW = availWidth - firstW

                if firstW < minWidth || secondW < minWidth {
                    // Min size guard: stack remaining windows in this cell
                    for remId in ids[i...] { result[remId] = remainingRect.integral }
                    return result
                }

                let firstRect = CGRect(
                    x: remainingRect.minX,
                    y: remainingRect.minY,
                    width: firstW,
                    height: remainingRect.height
                ).integral
                result[id] = firstRect

                remainingRect = CGRect(
                    x: remainingRect.minX + firstW + gaps.inner,
                    y: remainingRect.minY,
                    width: secondW,
                    height: remainingRect.height
                )
            } else {
                let availHeight = remainingRect.height - gaps.inner
                guard availHeight > 0 else {
                    for remId in ids[i...] { result[remId] = remainingRect.integral }
                    return result
                }

                let firstH = floor(availHeight * ratio)
                let secondH = availHeight - firstH

                if firstH < minHeight || secondH < minHeight {
                    // Min size guard: stack remaining windows in this cell
                    for remId in ids[i...] { result[remId] = remainingRect.integral }
                    return result
                }

                let firstRect = CGRect(
                    x: remainingRect.minX,
                    y: remainingRect.minY,
                    width: remainingRect.width,
                    height: firstH
                ).integral
                result[id] = firstRect

                remainingRect = CGRect(
                    x: remainingRect.minX,
                    y: remainingRect.minY + firstH + gaps.inner,
                    width: remainingRect.width,
                    height: secondH
                )
            }
        }

        if let lastID = ids.last {
            result[lastID] = remainingRect.integral
        }

        return result
    }

    // MARK: - Master-Stack Algorithm

    private static func layoutMasterStack(
        ids: [WindowID],
        usable: CGRect,
        gaps: Gaps,
        splitRatio: CGFloat
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        let ratio = min(0.85, max(0.15, splitRatio))

        let availWidth = usable.width - gaps.inner
        let masterW = floor(availWidth * ratio)
        let stackW = availWidth - masterW

        if masterW < minWidth || stackW < minWidth {
            // Cannot split into master + stack columns: stack all in usable
            for id in ids { result[id] = usable }
            return result
        }

        let masterRect = CGRect(
            x: usable.minX,
            y: usable.minY,
            width: masterW,
            height: usable.height
        ).integral
        result[ids[0]] = masterRect

        let stackIDs = Array(ids[1...])
        let stackCount = stackIDs.count
        guard stackCount > 0 else { return result }

        let totalInnerGaps = CGFloat(stackCount - 1) * gaps.inner
        let availHeight = usable.height - totalInnerGaps
        let heightPerWindow = floor(availHeight / CGFloat(stackCount))

        let stackX = usable.minX + masterW + gaps.inner

        if heightPerWindow < minHeight {
            // Min height guard: stack all secondary windows in the stack column
            let stackArea = CGRect(x: stackX, y: usable.minY, width: stackW, height: usable.height).integral
            for id in stackIDs { result[id] = stackArea }
            return result
        }

        for j in 0 ..< stackCount {
            let id = stackIDs[j]
            let y = usable.minY + CGFloat(j) * (heightPerWindow + gaps.inner)
            let h = (j == stackCount - 1) ? (usable.maxY - y) : heightPerWindow

            result[id] = CGRect(x: stackX, y: y, width: stackW, height: h).integral
        }

        return result
    }
}
