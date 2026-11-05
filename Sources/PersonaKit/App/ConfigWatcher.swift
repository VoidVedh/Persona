import Foundation
import PersonaCore

/// Watches the user's Persona support directory for changes to `config.json` and triggers hot-reload.
/// Strictly adheres to I8: never creates `config.json` if absent.
public final class ConfigWatcher {
    public static let shared = ConfigWatcher()

    private var dirFD: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var debounceTimer: DispatchSourceTimer?
    private var watchedDirectory: URL?
    private var lastSignature: String = ""

    public init() {}

    public func start(supportDir: URL, onReload: (@Sendable () -> Void)? = nil) {
        stop()
        watchedDirectory = supportDir

        guard FileManager.default.fileExists(atPath: supportDir.path) else {
            return
        }

        let configURL = supportDir.appendingPathComponent("config.json")
        lastSignature = Self.fileSignature(for: configURL)

        let fd = open(supportDir.path, O_EVTONLY)
        guard fd >= 0 else { return }
        self.dirFD = fd

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: .main
        )

        src.setEventHandler { [weak self] in
            self?.scheduleCheck(configURL: configURL, onReload: onReload)
        }

        src.setCancelHandler {
            close(fd)
        }

        src.resume()
        self.source = src
    }

    public func stop() {
        debounceTimer?.cancel()
        debounceTimer = nil
        source?.cancel()
        source = nil
        dirFD = -1
        watchedDirectory = nil
    }

    private func scheduleCheck(configURL: URL, onReload: (@Sendable () -> Void)?) {
        debounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: [], queue: .main)
        timer.schedule(deadline: .now() + .milliseconds(250))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.debounceTimer?.cancel()
            self.debounceTimer = nil

            let newSig = Self.fileSignature(for: configURL)
            guard newSig != self.lastSignature else { return }
            self.lastSignature = newSig

            if let onReload = onReload {
                onReload()
            } else {
                Task { @MainActor in
                    CommandRouter.shared.send(.reloadTheme)
                }
            }
        }
        timer.resume()
        debounceTimer = timer
    }

    private static func fileSignature(for url: URL) -> String {
        guard FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
            return "absent"
        }
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        return "\(mtime)-\(size)"
    }
}

