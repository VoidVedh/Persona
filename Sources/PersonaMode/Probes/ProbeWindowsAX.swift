import AppKit
import CoreGraphics
import Foundation
import PersonaCore
import PersonaKit

public enum ProbeWindowsAX: Probe {
    public static func run(args: [String]) -> Int32 {
        let provider = SystemAXWindowProvider()
        let appKitScreen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1512, height: 982)
        let primaryH = NSScreen.screens.first?.frame.height ?? appKitScreen.height
        let screenAX = CoordinateSpace.toAX(appKitScreen, primaryHeight: primaryH)
        let windows = provider.getWindows(on: screenAX)

        let list: [[String: Any]] = windows.map { win in
            [
                "id": win.id,
                "pid": win.pid,
                "bundleId": win.bundleId,
                "title": win.title,
                "frame": [win.frame.minX, win.frame.minY, win.frame.width, win.frame.height],
                "tilable": win.isTilable,
                "resizable": win.isResizable,
                "minimized": win.isMinimized,
                "fullscreen": win.isFullscreen
            ]
        }

        let dict: [String: Any] = [
            "count": list.count,
            "windows": list
        ]

        ProbeIO.emit(dict, args: args)
        return 0
    }
}
