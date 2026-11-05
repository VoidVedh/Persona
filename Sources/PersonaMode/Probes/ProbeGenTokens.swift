import Foundation
import PersonaCore
import PersonaKit

/// Regenerates `Resources/webui/css/tokens.css` from `ThemeTokens.swift` (§5.2, §12.1).
@MainActor
public enum ProbeGenTokens: Probe {
    public static func run(args: [String]) -> Int32 {
        guard let resDir = ResourceLocator.resourceDirectory() else {
            fputs("Error: could not locate Resources directory\n", stderr)
            return 1
        }
        let cssDir = resDir.appendingPathComponent("webui/css", isDirectory: true)
        try? FileManager.default.createDirectory(at: cssDir, withIntermediateDirectories: true)
        let outURL = cssDir.appendingPathComponent("tokens.css")
        let css = ThemeTokens.generateTokensCSS()

        do {
            try css.write(to: outURL, atomically: true, encoding: .utf8)
            return ProbeIO.emit([
                "tokenCount": ThemeTokens.webCSSTokens.count,
                "written": outURL.path,
            ], args: args)
        } catch {
            fputs("Error writing tokens.css: \(error)\n", stderr)
            return 1
        }
    }
}

