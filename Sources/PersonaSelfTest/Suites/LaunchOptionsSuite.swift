import Foundation
import PersonaCore

public enum LaunchOptionsSuite {
    public static func run(_ t: Harness) {
        t.suite("launchoptions") {
            // 1. Default (no args, no env) -> live + windowMoves + guardian
            let def = LaunchOptions.parse(args: [], env: [:])
            t.expectEqual(def.runMode, .live, "default runMode is .live")
            t.expect(def.windowMoves, "default windowMoves is true")
            t.expect(def.guardian, "default guardian is true")
            t.expect(!def.debugWebUI, "default debugWebUI is false")
            t.expectEqual(def.deprecatedEnvWarnings.count, 0, "no deprecation warnings by default")

            // 2. CLI --dry-run
            let cliDry = LaunchOptions.parse(args: ["--dry-run"], env: [:])
            t.expectEqual(cliDry.runMode, .dryRun, "--dry-run sets runMode to .dryRun")
            t.expect(!cliDry.windowMoves, "--dry-run disables windowMoves")
            t.expect(cliDry.guardian, "--dry-run keeps guardian enabled unless disabled")

            // 3. Env PERSONA_DRY_RUN=1
            let envDry = LaunchOptions.parse(args: [], env: ["PERSONA_DRY_RUN": "1"])
            t.expectEqual(envDry.runMode, .dryRun, "PERSONA_DRY_RUN=1 sets runMode to .dryRun")
            t.expect(!envDry.windowMoves, "PERSONA_DRY_RUN=1 disables windowMoves")

            // 4. CLI --dry-run beats PERSONA_DRY_RUN=0
            let cliWins = LaunchOptions.parse(args: ["--dry-run"], env: ["PERSONA_DRY_RUN": "0"])
            t.expectEqual(cliWins.runMode, .dryRun, "CLI --dry-run overrides PERSONA_DRY_RUN=0")
            t.expect(!cliWins.windowMoves, "CLI --dry-run disables windowMoves even with PERSONA_DRY_RUN=0")

            // 5. --no-window-moves keeps runMode == .live while freezing windows
            let noMovesCLI = LaunchOptions.parse(args: ["--no-window-moves"], env: [:])
            t.expectEqual(noMovesCLI.runMode, .live, "--no-window-moves keeps runMode == .live")
            t.expect(!noMovesCLI.windowMoves, "--no-window-moves sets windowMoves = false")

            let noMovesEnv = LaunchOptions.parse(args: [], env: ["PERSONA_NO_WINDOW_MOVES": "1"])
            t.expectEqual(noMovesEnv.runMode, .live, "PERSONA_NO_WINDOW_MOVES=1 keeps runMode == .live")
            t.expect(!noMovesEnv.windowMoves, "PERSONA_NO_WINDOW_MOVES=1 sets windowMoves = false")

            // 6. PERSONA_PHASE1_DEMO=1 -> deprecated warning, still live + windowMoves
            let legacy = LaunchOptions.parse(args: [], env: ["PERSONA_PHASE1_DEMO": "1"])
            t.expectEqual(legacy.runMode, .live, "PERSONA_PHASE1_DEMO=1 still runs in .live mode")
            t.expect(legacy.windowMoves, "PERSONA_PHASE1_DEMO=1 does not disable windowMoves")
            t.expectEqual(legacy.deprecatedEnvWarnings.count, 1, "PERSONA_PHASE1_DEMO=1 emits 1 deprecation warning")

            // 7. --no-guardian and --debug-webui and garbage args ignored
            let combo = LaunchOptions.parse(
                args: ["--no-guardian", "--debug-webui", "--unknown-flag", "-psn_0_12345"],
                env: [:]
            )
            t.expectEqual(combo.runMode, .live, "unknown flags ignored, runMode == .live")
            t.expect(!combo.guardian, "--no-guardian disables guardian")
            t.expect(combo.debugWebUI, "--debug-webui enables debugWebUI")
        }
    }
}

