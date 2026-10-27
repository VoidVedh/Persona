import Foundation
import PersonaCore

public enum GuardianLauncher {
    public static func resolveScriptsDir() -> URL? {
        if let env = ProcessInfo.processInfo.environment["PERSONA_SCRIPTS_DIR"], !env.isEmpty {
            let u = URL(fileURLWithPath: env)
            if FileManager.default.fileExists(atPath: u.appendingPathComponent("guardian.sh").path) {
                return u
            }
        }

        if let bundleResources = Bundle.main.resourceURL {
            let u = bundleResources.appendingPathComponent("scripts")
            if FileManager.default.fileExists(atPath: u.appendingPathComponent("guardian.sh").path) {
                return u
            }
        }

        let repoScripts = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("scripts")
        if FileManager.default.fileExists(atPath: repoScripts.appendingPathComponent("guardian.sh").path) {
            return repoScripts
        }

        return nil
    }

    @discardableResult
    public static func spawn(pid: pid_t = ProcessInfo.processInfo.processIdentifier, supportDir: URL) -> pid_t? {
        if ProcessInfo.processInfo.environment["PERSONA_NO_GUARDIAN"] == "1" {
            return nil
        }

        guard let scriptsDir = resolveScriptsDir() else {
            fputs("GuardianLauncher: could not locate scripts directory\n", stderr)
            return nil
        }

        let guardianScript = scriptsDir.appendingPathComponent("guardian.sh").path
        let restoreScript = scriptsDir.appendingPathComponent("restore_macos.sh").path

        guard FileManager.default.fileExists(atPath: guardianScript),
              FileManager.default.fileExists(atPath: restoreScript) else {
            fputs("GuardianLauncher: guardian.sh or restore_macos.sh missing\n", stderr)
            return nil
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        posix_spawn_file_actions_addopen(&fileActions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&fileActions, STDERR_FILENO, "/dev/null", O_WRONLY, 0)

        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }

        let flags: Int16 = Int16(POSIX_SPAWN_SETSID)
        posix_spawnattr_setflags(&attr, flags)

        let bash = "/bin/bash"
        let args: [String] = [bash, guardianScript, "\(pid)", supportDir.path, restoreScript]
        let cArgs: [UnsafeMutablePointer<CChar>?] = args.map { strdup($0) } + [nil]
        defer {
            for ptr in cArgs where ptr != nil {
                free(ptr)
            }
        }

        var guardianPid: pid_t = 0
        let spawnStatus = posix_spawn(&guardianPid, bash, &fileActions, &attr, cArgs, environ)
        guard spawnStatus == 0 else {
            fputs("posix_spawn failed for guardian: \(spawnStatus)\n", stderr)
            return nil
        }

        let lockMeta = supportDir.appendingPathComponent("session.lock.guardian")
        try? "\(guardianPid)\n".write(to: lockMeta, atomically: true, encoding: .utf8)

        return guardianPid
    }
}
