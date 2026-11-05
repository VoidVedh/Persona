import AppKit
import Foundation
import PersonaCore
import PersonaKit

public enum ProbeGenTerminalProfile {
    public static func run(args: [String]) -> Int32 {
        let outPath = ProbeIO.string(of: "--out", in: args)
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Resources/profiles/terminal-app/Persona3Reload.terminal").path
        let outURL = URL(fileURLWithPath: outPath)
        do {
            try TerminalAppProfile.writeProfile(to: outURL)
            print("Generated Terminal.app profile at \(outURL.path)")
            return 0
        } catch {
            fputs("probe gen-terminal-profile failed: \(error)\n", stderr)
            return 1
        }
    }
}

public enum ProbeProfiles {
    private struct Output: Encodable {
        let dir: String
        let files: [String]
        let unresolvedPlaceholders: Int
    }

    public static func run(args: [String]) -> Int32 {
        do {
            let renderedDir = try ProfileRenderer.shared.render(mutator: nil)
            let fm = FileManager.default
            var relFiles: [String] = []
            var unresolvedCount = 0

            let canonicalRoot = renderedDir.resolvingSymlinksInPath().path
            if let enumerator = fm.enumerator(at: renderedDir, includingPropertiesForKeys: [.isDirectoryKey]) {
                for case let url as URL in enumerator {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if !isDir {
                        let canonicalFile = url.resolvingSymlinksInPath().path
                        let rel = canonicalFile.replacingOccurrences(of: canonicalRoot + "/", with: "")
                        relFiles.append(rel)
                        if let content = try? String(contentsOf: url, encoding: .utf8),
                           content.contains("{{PROFILE_DIR}}") {
                            unresolvedCount += 1
                        }
                    }
                }
            }
            relFiles.sort()

            let payload = Output(
                dir: renderedDir.path,
                files: relFiles,
                unresolvedPlaceholders: unresolvedCount
            )

            // Clean up automatically after 2 seconds so immediate shell assertions (`ls` / `grep`) succeed
            // while leaving zero residue behind after the probe finishes.
            let baseTmp = renderedDir.deletingLastPathComponent().path
            if !args.contains("--keep") {
                let cleanupProc = Process()
                cleanupProc.executableURL = URL(fileURLWithPath: "/bin/sh")
                cleanupProc.arguments = ["-c", "sleep 2 && rm -rf \"\(baseTmp)\""]
                cleanupProc.standardOutput = FileHandle.nullDevice
                cleanupProc.standardError = FileHandle.nullDevice
                try? cleanupProc.run()
            }

            return ProbeIO.emit(payload, args: args)
        } catch {
            fputs("probe profiles failed: \(error)\n", stderr)
            return 1
        }
    }
}

public enum ProbeTerminalDetect {
    private struct Output: Encodable {
        let chosen: String
        let available: [String]
        let executableOrAppPath: String
        let fastfetchAvailable: Bool
        let sampleCommand: [String]
    }

    public static func run(args: [String]) -> Int32 {
        let res = TerminalLauncher.shared.detect()
        let dummyDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("PersonaMode/profiles")
        let cmd = TerminalLauncher.shared.buildCommand(chosen: res.chosen, profileDir: dummyDir)
        let out = Output(
            chosen: res.chosen,
            available: res.available,
            executableOrAppPath: res.executableOrAppPath,
            fastfetchAvailable: res.fastfetchAvailable,
            sampleCommand: cmd
        )
        return ProbeIO.emit(out, args: args)
    }
}

@MainActor
public enum ProbeStatusBar {
    private struct Output: Encodable {
        let installedAfterStart: Bool
        let itemCount: Int
        let titles: [String]
        let installedAfterStop: Bool
    }

    public static func run(args: [String]) -> Int32 {
        _ = NSApplication.shared
        let ctrl = StatusBarController.shared
        ctrl.start()
        let installedStart = ctrl.isInstalled
        let titles = (ctrl.menu?.items ?? []).compactMap { $0.isSeparatorItem ? nil : $0.title }
        let count = titles.count
        ctrl.stop()
        let installedStop = ctrl.isInstalled

        let out = Output(
            installedAfterStart: installedStart,
            itemCount: count,
            titles: titles,
            installedAfterStop: installedStop
        )
        return ProbeIO.emit(out, args: args)
    }
}

@MainActor
public enum ProbeCtl {
    private struct Output: Encodable {
        let commandsTested: [String]
        let receivedCount: Int
        let allMatched: Bool
    }

    public static func run(args: [String]) -> Int32 {
        var received: [PersonaCommand] = []
        let router = CommandRouter.shared
        router.onTile = { received.append(.tileNow) }
        router.onToggleFloat = { received.append(.toggleFloatFocused) }
        router.onReloadTheme = { received.append(.reloadTheme) }
        router.onToggleDarkHour = { received.append(.toggleDarkHour) }
        router.onOpenTerminal = { received.append(.openTerminal) }
        router.onShowLauncher = { received.append(.showLauncher) }
        router.onToggleLauncher = { received.append(.toggleLauncher) }

        let inputs = ["tile", "float", "reload", "darkhour", "terminal", "launcher"]
        for raw in inputs {
            if let cmd = PersonaCommand.from(string: raw) {
                router.send(cmd)
            }
        }

        let expected: [PersonaCommand] = [
            .tileNow, .toggleFloatFocused, .reloadTheme, .toggleDarkHour, .openTerminal, .showLauncher
        ]
        let out = Output(
            commandsTested: inputs,
            receivedCount: received.count,
            allMatched: received == expected
        )
        return ProbeIO.emit(out, args: args)
    }
}

