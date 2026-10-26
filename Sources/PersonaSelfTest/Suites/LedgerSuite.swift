import Foundation
import PersonaCore

public enum LedgerSuite {
    public static func run(_ t: Harness) {
        t.suite("ledger") {
            var ledger = RestoreLedger()
            t.expectEqual(ledger.entries.count, 0, "initial ledger is empty")
            t.expectEqual(ledger.pendingOrApplied.count, 0, "initial pendingOrApplied is empty")

            // 1. Append pending mutations
            let id1 = ledger.append(.dockAutohide(true))
            _ = ledger.append(.menuBarAutohide(true))
            _ = ledger.append(.tempDir(path: "/tmp/test"))

            t.expectEqual(ledger.entries.count, 3, "three entries recorded")
            t.expectEqual(ledger.pendingOrApplied.count, 3, "three entries are pending or applied")
            t.expectEqual(ledger.entries[0].status, .pending, "first entry is pending")

            // 2. Mark applied
            ledger.markApplied(id1)
            t.expectEqual(ledger.entries[0].status, .applied, "first entry is now applied")
            t.expectEqual(ledger.pendingOrApplied.count, 3, "applied entries are still in pendingOrApplied")

            // 3. Mark restored
            ledger.markRestored(id1)
            t.expectEqual(ledger.entries[0].status, .restored, "first entry is now restored")
            t.expectEqual(ledger.pendingOrApplied.count, 2, "restored entries are excluded from pendingOrApplied")

            // 4. Mutation equality & encoding roundtrip
            let mut = Mutation.dockAutohide(true)
            let data = try? JSONEncoder().encode(mut)
            t.expect(data != nil, "mutation is encodable")
            if let d = data {
                let decoded = try? JSONDecoder().decode(Mutation.self, from: d)
                t.expectEqual(decoded, mut, "mutation survives JSON roundtrip")
            }
        }
    }
}
