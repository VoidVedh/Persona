import Foundation
import PersonaCore
import PersonaKit

public enum ProbeApps: Probe {
    public static func run(args: [String]) -> Int32 {
        let query = ProbeIO.string(of: "--query", in: args) ?? ""
        let matches = AppIndexer.shared.search(query: query)
        let totalIndexed = AppIndexer.shared.indexedAppCount

        let results: [[String: Any]] = matches.prefix(25).map { entry in
            [
                "id": entry.item.id,
                "name": entry.item.name,
                "kind": entry.item.isAction ? "action" : "app",
                "score": entry.score
            ]
        }

        let dict: [String: Any] = [
            "count": totalIndexed,
            "matchCount": matches.count,
            "query": query,
            "results": results
        ]
        return ProbeIO.emit(dict, args: args)
    }
}

