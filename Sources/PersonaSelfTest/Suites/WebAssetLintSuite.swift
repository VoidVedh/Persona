import Foundation
import PersonaCore
import PersonaKit

public enum WebAssetLintSuite {
    public static func run(_ t: Harness) {
        t.suite("weblint") {
            guard let resDir = ResourceLocator.resourceDirectory() else {
                t.fail("ResourceLocator.resourceDirectory() returned nil")
                return
            }
            let webuiDir = resDir.appendingPathComponent("webui", isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: webuiDir,
                includingPropertiesForKeys: nil
            ) else {
                t.fail("Failed to enumerate Resources/webui")
                return
            }

            var checkedFiles = 0
            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                guard ["html", "css", "js", "svg"].contains(ext) else { continue }
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
                let relName = fileURL.path.replacingOccurrences(of: webuiDir.path + "/", with: "")
                checkedFiles += 1

                // 1. Forbidden DOM/JS APIs (§4.3, §12.2)
                if ext == "js" || ext == "html" {
                    t.expect(!content.contains("innerHTML"), "\(relName): no innerHTML")
                    t.expect(!content.contains("outerHTML"), "\(relName): no outerHTML")
                    t.expect(!content.contains("eval("), "\(relName): no eval(")
                    t.expect(!content.contains("new Function"), "\(relName): no new Function")
                }

                // 2. No network URLs (allow standard SVG namespace declaration only)
                let strippedSVGNS = content
                    .replacingOccurrences(of: "http://www.w3.org/2000/svg", with: "")
                    .replacingOccurrences(of: "http://www.w3.org/1999/xlink", with: "")
                t.expect(!strippedSVGNS.contains("http://"), "\(relName): no http:// literal")
                t.expect(!strippedSVGNS.contains("https://"), "\(relName): no https:// literal")

                // 3. CSS lint: no rule block may contain both `filter:` and `clip-path:` (R-V2-4)
                if ext == "css" {
                    let withoutComments = stripCSSComments(content)
                    let blocks = withoutComments.components(separatedBy: "}")
                    var filterClipViolation = false
                    for block in blocks {
                        guard let openBrace = block.firstIndex(of: "{") else { continue }
                        let body = String(block[block.index(after: openBrace)...]).lowercased()
                        let hasFilter = body.range(of: "(^|;|\\s)filter\\s*:", options: .regularExpression) != nil
                        let hasClipPath = body.range(of: "(^|;|\\s)clip-path\\s*:", options: .regularExpression) != nil
                        if hasFilter && hasClipPath {
                            filterClipViolation = true
                        }
                    }
                    t.expect(!filterClipViolation, "\(relName): no CSS rule combines filter and clip-path")
                }
            }

            t.expect(checkedFiles >= 6, "linted at least 6 webui files (found \(checkedFiles))")
        }
    }

    private static func stripCSSComments(_ css: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/", options: []) else {
            return css
        }
        let range = NSRange(css.startIndex..<css.endIndex, in: css)
        return regex.stringByReplacingMatches(in: css, options: [], range: range, withTemplate: "")
    }
}

