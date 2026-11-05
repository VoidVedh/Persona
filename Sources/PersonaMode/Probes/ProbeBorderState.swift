import CoreGraphics
import Foundation
import PersonaCore
import PersonaKit

public enum ProbeBorderState: Probe {
    public static func run(args: [String]) -> Int32 {
        let controller = BorderController.shared
        controller.start()

        let seconds = ProbeIO.double(of: "--seconds", in: args, default: 0.1)
        if seconds > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(seconds))
        }

        var frameArray: [Double]?
        if let f = controller.currentBorderFrameAppKit {
            frameArray = [Double(f.origin.x), Double(f.origin.y), Double(f.size.width), Double(f.size.height)]
        }

        var dict: [String: Any] = [
            "visible": controller.isBorderVisible,
            "targetWindowId": controller.currentFocusedID ?? 0
        ]
        if let fa = frameArray {
            dict["frame"] = fa
        }

        controller.stop()
        ProbeIO.emit(dict, args: args)
        return 0
    }
}
