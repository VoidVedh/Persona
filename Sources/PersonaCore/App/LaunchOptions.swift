import Foundation

public enum PersonaRunMode: String, Codable, Equatable {
    case live
    case dryRun
}

/// Pure launch-option parser normalizing CLI flags and environment variables.
/// CLI flags always take precedence over environment variables.
public struct LaunchOptions: Equatable {
    public var runMode: PersonaRunMode
    public var windowMoves: Bool
    public var guardian: Bool
    public var debugWebUI: Bool
    public var deprecatedEnvWarnings: [String]

    public init(
        runMode: PersonaRunMode = .live,
        windowMoves: Bool = true,
        guardian: Bool = true,
        debugWebUI: Bool = false,
        deprecatedEnvWarnings: [String] = []
    ) {
        self.runMode = runMode
        self.windowMoves = windowMoves
        self.guardian = guardian
        self.debugWebUI = debugWebUI
        self.deprecatedEnvWarnings = deprecatedEnvWarnings
    }

    public static func parse(
        args: [String] = Array(CommandLine.arguments.dropFirst()),
        env: [String: String] = ProcessInfo.processInfo.environment
    ) -> LaunchOptions {
        var warnings: [String] = []
        if env["PERSONA_PHASE1_DEMO"] != nil {
            warnings.append("PERSONA_PHASE1_DEMO is deprecated and ignored. Persona Mode now runs LIVE by default; use --dry-run (PERSONA_DRY_RUN=1) or --no-window-moves (PERSONA_NO_WINDOW_MOVES=1).")
        }

        let hasDryRunFlag = args.contains("--dry-run")
        let hasLiveFlag = args.contains("--live")
        let envDryRun = env["PERSONA_DRY_RUN"] == "1"

        let isDryRun: Bool
        if hasDryRunFlag {
            isDryRun = true
        } else if hasLiveFlag {
            isDryRun = false
        } else {
            isDryRun = envDryRun
        }

        let runMode: PersonaRunMode = isDryRun ? .dryRun : .live

        let hasNoWindowMovesFlag = args.contains("--no-window-moves")
        let envNoWindowMoves = env["PERSONA_NO_WINDOW_MOVES"] == "1"
        let windowMoves: Bool
        if isDryRun || hasNoWindowMovesFlag || envNoWindowMoves {
            windowMoves = false
        } else {
            windowMoves = true
        }

        let hasNoGuardianFlag = args.contains("--no-guardian")
        let envNoGuardian = env["PERSONA_NO_GUARDIAN"] == "1"
        let guardian = !(hasNoGuardianFlag || envNoGuardian)

        let hasDebugWebUIFlag = args.contains("--debug-webui")
        let envDebugWebUI = env["PERSONA_WEBUI_DEBUG"] == "1"
        let debugWebUI = hasDebugWebUIFlag || envDebugWebUI

        return LaunchOptions(
            runMode: runMode,
            windowMoves: windowMoves,
            guardian: guardian,
            debugWebUI: debugWebUI,
            deprecatedEnvWarnings: warnings
        )
    }

    /// Exports normalized environment variables via `setenv` so deep subsystems
    /// (`WindowRegistry`, `TerminalLauncher`, `GuardianLauncher`) read consistent flags.
    public func applyToProcessEnvironment() {
        setenv("PERSONA_DRY_RUN", runMode == .dryRun ? "1" : "0", 1)
        setenv("PERSONA_NO_WINDOW_MOVES", windowMoves ? "0" : "1", 1)
        if !guardian {
            setenv("PERSONA_NO_GUARDIAN", "1", 1)
        }
        if debugWebUI {
            setenv("PERSONA_WEBUI_DEBUG", "1", 1)
        }
    }
}

