import Foundation

/// Name -> probe dispatch for `PersonaMode --probe <name> [args…]`.
@MainActor
public enum ProbeRegistry {
    public static let names = [
        "snapshot", "windows", "windows-of",
    ]

    /// Runs the named probe; returns `nil` if the name is unknown.
    public static func run(name: String, args: [String]) -> Int32? {
        switch name {
        case "snapshot": return ProbeSnapshot.run(args: args)
        case "windows": return ProbeWindows.run(args: args)
        case "windows-of": return ProbeWindowsOf.run(args: args)
        default: return nil
        }
    }
}
