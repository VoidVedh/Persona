import Foundation
import PersonaCore

let suites: [(name: String, run: (Harness) -> Void)] = [
    ("harness", HarnessSuite.run),
    ("config", ConfigSuite.run),
    ("state", StateSuite.run),
    ("ledger", LedgerSuite.run),
    ("mutator", MutatorSuite.run),
    ("restore", RestoreSuite.run),
    ("coords", CoordSuite.run),
    ("windows", WindowSuite.run),
    ("theme", ThemeSuite.run),
    ("telemetry", TelemetrySuite.run),
    ("layout", LayoutSuite.run),
    ("fuzzy", FuzzySuite.run),
    ("launchoptions", LaunchOptionsSuite.run),
    ("timeofday", TimeOfDaySuite.run),
    ("moonphase", MoonPhaseSuite.run),
    ("webstate", WebStateSuite.run),
    ("webrouter", WebRouterSuite.run),
    ("websurface", WebSurfaceSuite.run),
    ("tokendrift", TokenDriftSuite.run),
    ("weblint", WebAssetLintSuite.run)
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
