import ApplicationServices
import Foundation
import PersonaCore
import PersonaKit

public enum ProbeAX: Probe {
    public static func run(args: [String]) -> Int32 {
        let isTrusted = AXPermission.shared.isTrusted
        let bundleId = Bundle.main.bundleIdentifier ?? "dev.persona.mode"
        let execPath = Bundle.main.executablePath ?? CommandLine.arguments[0]

        let dict: [String: Any] = [
            "trusted": isTrusted,
            "bundleId": bundleId,
            "executablePath": execPath
        ]

        ProbeIO.emit(dict, args: args)
        return 0
    }
}
