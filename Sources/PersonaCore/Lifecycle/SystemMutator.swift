import Foundation

public final class SystemMutator {
    public let store: StateStore
    public let adapter: SystemAdapter
    public private(set) var state: StateFile

    public init(store: StateStore, adapter: SystemAdapter, state: StateFile) {
        self.store = store
        self.adapter = adapter
        self.state = state
    }

    public func apply(_ m: Mutation) throws {
        // I3: Write-ahead ledger: append pending -> store.save -> adapter call -> markApplied -> store.save
        let entryId = state.ledger.append(m, status: .pending)
        try store.save(state)

        do {
            // I7: Exhaustive switch over Mutation
            switch m {
            case .dockAutohide(let value):
                try adapter.setDockAutohide(value)
            case .menuBarAutohide(let value):
                try adapter.setMenuBarAutohide(value)
            case .systemWallpaper(let path):
                let snap = WallpaperSnapshot(
                    displayUUID: "primary",
                    name: "Primary",
                    url: path,
                    options: nil,
                    isRestorable: true
                )
                try adapter.setWallpapers([snap])
            case .terminalProfile:
                break
            case .tempDir:
                break
            }

            state.ledger.markApplied(entryId)
            try store.save(state)
        } catch {
            // Re-throw leaving the entry marked as pending in state file so recovery treats it properly
            throw error
        }
    }
}
