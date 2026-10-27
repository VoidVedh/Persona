import AppKit
import Foundation
import PersonaCore

public enum SignalGuard {
    private static var signalSources: [DispatchSourceSignal] = []

    public static func install() {
        // Standard graceful termination signals: SIGINT, SIGTERM, SIGHUP, SIGQUIT
        let gracefulSignals: [Int32] = [SIGINT, SIGTERM, SIGHUP, SIGQUIT]

        for sig in gracefulSignals {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler {
                NSApp?.terminate(nil)
            }
            src.resume()
            signalSources.append(src)
        }

        // Fatal crash signals: SEGV, BUS, ILL, ABRT, TRAP, FPE
        let fatalSignals: [Int32] = [SIGSEGV, SIGBUS, SIGILL, SIGABRT, SIGTRAP, SIGFPE]
        for sig in fatalSignals {
            var action = sigaction()
            action.__sigaction_u.__sa_handler = { signum in
                // Async-signal-safe immediate exit: guardian watchdog detects PID death and restores
                _exit(128 + signum)
            }
            sigemptyset(&action.sa_mask)
            action.sa_flags = 0
            sigaction(sig, &action, nil)
        }

        // Uncaught NSException handler
        NSSetUncaughtExceptionHandler { exception in
            _ = RestoreService.shared?.restoreAll(reason: .exception)
        }
    }
}
