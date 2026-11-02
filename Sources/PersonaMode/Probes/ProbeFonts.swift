import AppKit
import Foundation
import PersonaKit

public enum ProbeFonts: Probe {
    public static func run(args: [String]) -> Int32 {
        Fonts.register()
        let rajdhani = Fonts.isAvailable(Fonts.rajdhaniSemiBoldName) || Fonts.isAvailable(Fonts.rajdhaniBoldName)
        let bebas = Fonts.isAvailable(Fonts.bebasName)

        let result: [String: Any] = [
            "rajdhani": rajdhani,
            "bebas": bebas
        ]
        return ProbeIO.emit(result, args: args)
    }
}
