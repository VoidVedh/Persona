import Foundation

/// Name -> probe dispatch for `PersonaMode --probe <name> [args…]`.
@MainActor
public enum ProbeRegistry {
    public static let names = [
        "snapshot", "windows", "windows-of", "fonts", "render",
        "telemetry", "focus", "spaces", "nowplaying", "nowplaying-inject"
    ]

    /// Runs the named probe; returns `nil` if the name is unknown.
    public static func run(name: String, args: [String]) -> Int32? {
        switch name {
        case "snapshot": return ProbeSnapshot.run(args: args)
        case "windows": return ProbeWindows.run(args: args)
        case "windows-of": return ProbeWindowsOf.run(args: args)
        case "fonts": return ProbeFonts.run(args: args)
        case "render": return ProbeRender.run(args: args)
        case "telemetry": return ProbeTelemetry.run(args: args)
        case "focus": return ProbeFocus.run(args: args)
        case "spaces": return ProbeSpaces.run(args: args)
        case "nowplaying": return ProbeNowPlaying.run(args: args)
        case "nowplaying-inject": return ProbeNowPlayingInject.run(args: args)
        default: return nil
        }
    }
}
