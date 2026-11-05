import Foundation
import PersonaCore
import PersonaKit

public enum TokenDriftSuite {
    public static func run(_ t: Harness) {
        t.suite("tokendrift") {
            guard let resDir = ResourceLocator.resourceDirectory() else {
                t.fail("ResourceLocator.resourceDirectory() returned nil")
                return
            }
            let tokensURL = resDir.appendingPathComponent("webui/css/tokens.css")
            guard let cssContent = try? String(contentsOf: tokensURL, encoding: .utf8) else {
                t.fail("Could not read Resources/webui/css/tokens.css")
                return
            }

            let expected = ThemeTokens.generateTokensCSS()
            t.expectEqual(cssContent, expected, "tokens.css matches ThemeTokens.generateTokensCSS() exactly")

            // Verify every individual token in ThemeTokens.webCSSTokens appears in :root
            for (name, value) in ThemeTokens.webCSSTokens {
                let needle = "\(name): \(value);"
                t.expect(cssContent.contains(needle), "tokens.css contains '\(needle)'")
            }
        }
    }
}

