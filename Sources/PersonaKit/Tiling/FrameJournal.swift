import CoreGraphics
import Foundation
import PersonaCore

/// Journal of original pre-tiled window frames, persisted to `windows.json` so user window
/// geometry can be restored exactly when exiting Persona Mode.
public final class FrameJournal {
    public struct Entry: Codable, Equatable {
        public let id: CGWindowID
        public let pid: pid_t
        public let bundleId: String
        public let frame: CGRect

        public init(id: CGWindowID, pid: pid_t, bundleId: String, frame: CGRect) {
            self.id = id
            self.pid = pid
            self.bundleId = bundleId
            self.frame = frame
        }
    }

    private let fileURL: URL?
    private var entries: [CGWindowID: Entry] = [:]
    private var debounceTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.persona.mode.journal", qos: .utility)

    public init(supportDir: URL? = nil) {
        self.fileURL = supportDir?.appendingPathComponent("windows.json")
        loadExisting()
    }

    public func recordIfNeeded(window: ManagedWindow) {
        queue.sync {
            guard self.entries[window.id] == nil else { return }

            let entry = Entry(
                id: window.id,
                pid: window.pid,
                bundleId: window.bundleId,
                frame: window.frame
            )
            self.entries[window.id] = entry
            self.scheduleSave()
        }
    }

    public func hasEntry(for windowID: CGWindowID) -> Bool {
        queue.sync { entries[windowID] != nil }
    }

    public func originalFrame(for windowID: CGWindowID) -> CGRect? {
        queue.sync { entries[windowID]?.frame }
    }

    public func restoreFrames(provider: AXWindowProvider, timeBudget: TimeInterval = 1.0) {
        if (provider is SystemAXWindowProvider) && SystemAXWindowProvider.areWindowMovesBlocked() {
            clear()
            return
        }
        let snapshot = queue.sync { Array(entries.values) }
        guard !snapshot.isEmpty else { return }

        let deadline = Date().addingTimeInterval(timeBudget)
        for entry in snapshot {
            guard Date() < deadline else { break }
            let dummy = ManagedWindow(
                id: entry.id,
                pid: entry.pid,
                bundleId: entry.bundleId,
                frame: entry.frame
            )
            _ = provider.setWindowFrame(window: dummy, frame: entry.frame)
        }

        clear()
    }

    public func clear() {
        queue.sync {
            entries.removeAll()
            debounceTimer?.cancel()
            debounceTimer = nil
            if let url = fileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func loadExisting() {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return }
        if let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            for entry in decoded {
                entries[entry.id] = entry
            }
        }
    }

    private func scheduleSave() {
        debounceTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        timer.schedule(deadline: .now() + .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.saveImmediate()
        }
        timer.resume()
        self.debounceTimer = timer
    }

    private func saveImmediate() {
        guard let url = fileURL else { return }
        let list = Array(entries.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
