import Foundation
import PersonaCore

/// Renders isolated terminal and CLI profiles into `$TMPDIR/PersonaMode/profiles/` with write-ahead ledgering.
/// Strictly avoids touching `~/.config`, `~/.zshrc`, or any user dotfiles.
public final class ProfileRenderer {
    public static let shared = ProfileRenderer()

    public private(set) var renderedDirectory: URL?

    public init() {}

    /// Locates the bundled or repository `Resources/profiles` directory.
    public static func resolveSourceProfilesDir() -> URL? {
        let fm = FileManager.default
        if let envDir = ProcessInfo.processInfo.environment["PERSONA_RESOURCE_DIR"] {
            let candidate = URL(fileURLWithPath: envDir).appendingPathComponent("profiles")
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        if let bundleRes = Bundle.main.resourceURL {
            let candidate = bundleRes.appendingPathComponent("profiles")
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        let cwdCandidate = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("Resources")
            .appendingPathComponent("profiles")
        if fm.fileExists(atPath: cwdCandidate.path) {
            return cwdCandidate
        }
        return nil
    }

    /// Renders `Resources/profiles/**` into `$TMPDIR/PersonaMode/profiles/`, substituting `{{PROFILE_DIR}}`.
    /// Records `.tempDir` write-ahead in `SystemMutator` before creating the directory when a mutator is provided.
    @discardableResult
    public func render(mutator: SystemMutator? = nil) throws -> URL {
        let fm = FileManager.default
        let baseTmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PersonaMode", isDirectory: true)
        let targetDir = baseTmp.appendingPathComponent("profiles", isDirectory: true)

        // Write-ahead ledger entry before creating temp directory
        try mutator?.apply(.tempDir(path: baseTmp.path))

        try fm.createDirectory(
            at: baseTmp,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        if fm.fileExists(atPath: targetDir.path) {
            try fm.removeItem(at: targetDir)
        }
        try fm.createDirectory(
            at: targetDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        if let sourceDir = Self.resolveSourceProfilesDir() {
            try copyAndSubstitute(from: sourceDir, to: targetDir, profileDirPath: targetDir.path)
        }

        // Ensure Terminal.app profile exists in the rendered directory
        let terminalProfileURL = targetDir
            .appendingPathComponent("terminal-app", isDirectory: true)
            .appendingPathComponent("Persona3Reload.terminal")
        if !fm.fileExists(atPath: terminalProfileURL.path) {
            try TerminalAppProfile.writeProfile(to: terminalProfileURL)
        }

        // Generate isolated shell launch script (`run.command`) inside the temp directory
        try writeLaunchScript(in: targetDir)

        self.renderedDirectory = targetDir
        return targetDir
    }

    /// Removes the rendered temporary directory (guarded by `RecoveryManager.isSafeToDelete`).
    public func cleanup(supportDir: URL? = nil) {
        let fm = FileManager.default
        let baseTmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PersonaMode", isDirectory: true)
        let fallbackSupport = supportDir ?? fm.temporaryDirectory
        if RecoveryManager.isSafeToDelete(path: baseTmp.path, supportDir: fallbackSupport) {
            try? fm.removeItem(at: baseTmp)
        }
        renderedDirectory = nil
    }

    private func copyAndSubstitute(from srcDir: URL, to dstDir: URL, profileDirPath: String) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: srcDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let textExtensions: Set<String> = ["jsonc", "json", "txt", "conf", "lua", "toml", "terminal", "sh", ""]

        for case let fileURL as URL in enumerator {
            let relPath = fileURL.path.replacingOccurrences(of: srcDir.path + "/", with: "")
            let destURL = dstDir.appendingPathComponent(relPath)

            let values = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try fm.createDirectory(at: destURL, withIntermediateDirectories: true)
                continue
            }

            try fm.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let ext = fileURL.pathExtension.lowercased()
            if textExtensions.contains(ext), let text = try? String(contentsOf: fileURL, encoding: .utf8) {
                let rendered = text.replacingOccurrences(of: "{{PROFILE_DIR}}", with: profileDirPath)
                try rendered.write(to: destURL, atomically: true, encoding: .utf8)
            } else {
                try fm.copyItem(at: fileURL, to: destURL)
            }
        }
    }

    private func writeLaunchScript(in profileDir: URL) throws {
        let fastfetchConf = profileDir.appendingPathComponent("fastfetch/config.jsonc").path
        let fastfetchLogo = profileDir.appendingPathComponent("fastfetch/logo.txt").path
        let scriptURL = profileDir.appendingPathComponent("run.command")

        let script = """
        #!/bin/bash
        export PERSONA_MODE=1
        clear
        if command -v fastfetch >/dev/null 2>&1; then
            fastfetch -c "\(fastfetchConf)" --logo-source "\(fastfetchLogo)"
        elif [ -x /opt/homebrew/bin/fastfetch ]; then
            /opt/homebrew/bin/fastfetch -c "\(fastfetchConf)" --logo-source "\(fastfetchLogo)"
        else
            printf "\\033[1;36m◈ PERSONA 3 RELOAD // DARK HOUR TERMINAL ◈\\033[0m\\n"
            printf "\\033[0;34m  S.E.E.S. SPECIAL EXTRACURRICULAR EXECUTION SQUAD\\033[0m\\n\\n"
        fi
        exec "${SHELL:-/bin/zsh}" -l
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }
}

