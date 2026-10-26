import Foundation
import PersonaCore

let suites: [(name: String, run: (Harness) -> Void)] = [
    ("harness", HarnessSuite.run)
]

let harness = Harness()
let args = Array(CommandLine.arguments.dropFirst())

let selectedSuites: [(name: String, run: (Harness) -> Void)]
if args.isEmpty {
    selectedSuites = suites
} else {
    selectedSuites = suites.filter { suite in
        args.contains(suite.name)
    }
}

for suite in selectedSuites {
    suite.run(harness)
}

print("=== Self-Test Summary: \(harness.passes) passed, \(harness.failures) failed ===")
exit(harness.failures == 0 ? 0 : 1)
