import Foundation

/// Locates bundled resources (fonts, profiles).
///
/// Order: `Contents/Resources` of the running `.app` → `PERSONA_RESOURCE_DIR` → `<repo>/Resources`
/// (found by walking up from the executable and the working directory to a `Package.swift`).
public enum ResourceLocator {
    public static func resourceDirectory(fileManager: FileManager = .default) -> URL? {
        if let bundled = Bundle.main.resourceURL,
           Bundle.main.bundleURL.pathExtension == "app",
           fileManager.fileExists(atPath: bundled.appendingPathComponent("fonts").path) {
            return bundled
        }
        if let env = ProcessInfo.processInfo.environment["PERSONA_RESOURCE_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        var starts: [URL] = []
        if let exe = Bundle.main.executableURL { starts.append(exe.deletingLastPathComponent()) }
        starts.append(URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true))
        for start in starts {
            var dir = start
            for _ in 0..<12 {
                let manifest = dir.appendingPathComponent("Package.swift")
                let resources = dir.appendingPathComponent("Resources")
                if fileManager.fileExists(atPath: manifest.path), fileManager.fileExists(atPath: resources.path) {
                    return resources
                }
                let parent = dir.deletingLastPathComponent()
                if parent == dir { break }
                dir = parent
            }
        }
        return nil
    }
}
