import Foundation

/// Removes empty/ephemeral WebKit cache folders that macOS may create under `~/Library`
/// even when `WKWebsiteDataStore.nonPersistent()` is used (§12.5).
/// Strictly scoped to `dev.persona.mode` and `PersonaMode` paths.
public enum WebCacheCleaner {
    public static func cleanup() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        let exactSubpaths = [
            "Library/WebKit/dev.persona.mode",
            "Library/WebKit/PersonaMode",
            "Library/Caches/dev.persona.mode",
            "Library/Caches/PersonaMode",
            "Library/HTTPStorages/dev.persona.mode",
            "Library/HTTPStorages/dev.persona.mode.binarycookies",
            "Library/HTTPStorages/PersonaMode",
            "Library/Saved Application State/dev.persona.mode.savedState",
        ]

        let libPrefix = home.appendingPathComponent("Library").standardizedFileURL.path + "/"
        for sub in exactSubpaths {
            let target = home.appendingPathComponent(sub).standardizedFileURL
            guard target.path.hasPrefix(libPrefix),
                  (target.lastPathComponent.contains("dev.persona.mode") || target.lastPathComponent == "PersonaMode"),
                  fm.fileExists(atPath: target.path) else {
                continue
            }
            try? fm.removeItem(at: target)
        }
    }
}

