import Foundation
import PersonaCore

public enum ConfigSuite {
    public static func run(_ t: Harness) {
        t.suite("config") {
            // 1. Defaults match config/default-config.json
            let defaultJsonURL = URL(fileURLWithPath: "config/default-config.json")
            if FileManager.default.fileExists(atPath: defaultJsonURL.path) {
                do {
                    let data = try Data(contentsOf: defaultJsonURL)
                    let decodedFromFile = try JSONDecoder().decode(AppConfig.self, from: data)
                    let constructedDefault = AppConfig()
                    t.expectEqual(decodedFromFile, constructedDefault, "decoded default-config.json matches constructed AppConfig()")
                } catch {
                    t.fail("Failed to decode config/default-config.json: \(error)")
                }
            } else {
                t.fail("config/default-config.json does not exist at repo root")
            }

            // 2. Partial JSON merges over defaults
            let partialJson = """
            {
                "tiling": {
                    "gaps": {
                        "outer": 20
                    }
                }
            }
            """
            do {
                let data = partialJson.data(using: .utf8)!
                let partialConfig = try JSONDecoder().decode(AppConfig.self, from: data)
                t.expectEqual(partialConfig.tiling.gaps.outer, 20, "partial outer gap is overridden")
                t.expectEqual(partialConfig.tiling.gaps.inner, 10, "partial inner gap maintains default")
                t.expectEqual(partialConfig.topBar.height, 44, "unmentioned topBar maintains default")
            } catch {
                t.fail("Failed to decode partial JSON: \(error)")
            }

            // 3. Garbage JSON falls back to defaults + produces a warning
            let tmpGarbageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("garbage_config.json")
            try? "{ not valid json ...".write(to: tmpGarbageURL, atomically: true, encoding: .utf8)
            let (garbageConfig, warnings) = AppConfig.load(userFile: tmpGarbageURL)
            t.expectEqual(garbageConfig, AppConfig(), "garbage JSON yields default config")
            t.expect(!warnings.isEmpty, "garbage JSON produces warning message")
            try? FileManager.default.removeItem(at: tmpGarbageURL)

            // 4. Clamping and validation tests
            var testConfig = AppConfig()
            testConfig.border.width = 15 // inner gap is 10
            testConfig.tiling.splitRatio = 0.95 // > 0.8
            testConfig.border.color = "invalid-hex"

            let clampWarnings = testConfig.validateAndClamp()
            t.expectEqual(testConfig.border.width, 10, "border width clamped to inner gap")
            t.expectEqual(testConfig.tiling.splitRatio, 0.8, "splitRatio clamped to 0.8")
            t.expectEqual(testConfig.border.color, "#00d8ff", "invalid hex color fallback")
            t.expectEqual(clampWarnings.count, 3, "three validation warnings generated")

            // Lower bound clamp test
            var lowerClampConfig = AppConfig()
            lowerClampConfig.tiling.splitRatio = 0.05
            lowerClampConfig.hud.fps = 5
            lowerClampConfig.hud.particles = -5
            lowerClampConfig.border.bracketLength = 8
            lowerClampConfig.sound.volume = -0.2
            _ = lowerClampConfig.validateAndClamp()
            t.expectEqual(lowerClampConfig.tiling.splitRatio, 0.2, "splitRatio clamped to 0.2")
            t.expectEqual(lowerClampConfig.hud.fps, 12, "hud.fps clamped to 12")
            t.expectEqual(lowerClampConfig.hud.particles, 0, "hud.particles clamped to 0")
            t.expectEqual(lowerClampConfig.border.bracketLength, 16, "border.bracketLength clamped to 16")
            t.expectEqual(lowerClampConfig.sound.volume, 0.0, "sound.volume clamped to 0.0")

            var upperClampConfig = AppConfig()
            upperClampConfig.hud.fps = 120
            upperClampConfig.hud.particles = 200
            upperClampConfig.border.bracketLength = 90
            upperClampConfig.sound.volume = 2.5
            _ = upperClampConfig.validateAndClamp()
            t.expectEqual(upperClampConfig.hud.fps, 30, "hud.fps clamped to 30")
            t.expectEqual(upperClampConfig.hud.particles, 48, "hud.particles clamped to 48")
            t.expectEqual(upperClampConfig.border.bracketLength, 48, "border.bracketLength clamped to 48")
            t.expectEqual(upperClampConfig.sound.volume, 1.0, "sound.volume clamped to 1.0")
        }
    }
}
