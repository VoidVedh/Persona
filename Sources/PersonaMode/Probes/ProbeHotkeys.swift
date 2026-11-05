import Foundation
import PersonaCore
import PersonaKit

public enum ProbeHotkeys: Probe {
    public static func run(args: [String]) -> Int32 {
        let config = AppConfig()
        let statuses = HotKeyCenter.shared.testStatus(config: config)

        var dict: [String: Any] = [:]
        for (chord, status) in statuses {
            dict[chord] = Int(status)
        }
        return ProbeIO.emit(dict, args: args)
    }
}

