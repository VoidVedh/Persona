import AppKit
import Foundation
import PersonaCore
import PersonaKit

let args = CommandLine.arguments

if args.count >= 2 && args[1] == "--restore-only" {
    let store = StateStore()
    let adapter = RealSystemAdapter()
    do {
        try RecoveryManager.recover(store: store, adapter: adapter)
        print("Restoration complete.")
        exit(0)
    } catch {
        fputs("Restore failed: \(error)\n", stderr)
        exit(1)
    }
}

if args.count >= 2 && args[1] == "--ctl" {
    let cmd = args.count >= 3 ? args[2] : ""
    DistributedNotificationCenter.default().postNotificationName(
        NSNotification.Name("dev.persona.mode.command"),
        object: nil,
        userInfo: ["cmd": cmd],
        deliverImmediately: true
    )
    exit(0)
}

if args.count >= 3 && args[1] == "--probe" {
    let probeName = args[2]
    let remainingArgs = Array(args.dropFirst(3))

    MainActor.assumeIsolated {
        guard let code = ProbeRegistry.run(name: probeName, args: remainingArgs) else {
            fputs("Unknown probe: \(probeName). Known: \(ProbeRegistry.names.joined(separator: ", "))\n", stderr)
            exit(1)
        }
        exit(code)
    }
}

// GUI default mode
let launchOptions = LaunchOptions.parse()
launchOptions.applyToProcessEnvironment()
for warning in launchOptions.deprecatedEnvWarnings {
    fputs("warning: \(warning)\n", stderr)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
