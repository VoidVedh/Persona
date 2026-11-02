import Foundation
import PersonaKit

public enum ProbeSpaces: Probe {
    public static func run(args: [String]) -> Int32 {
        let provider = SpaceProvider.shared
        provider.refresh()

        let snap = AppState.shared.spaceSnapshot
        let result: [String: Any] = [
            "available": snap.available,
            "count": snap.count,
            "active": snap.activeIndex
        ]
        return ProbeIO.emit(result, args: args)
    }
}
