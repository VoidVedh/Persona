import Foundation

public enum LedgerEntryStatus: String, Codable, Equatable {
    case pending
    case applied
    case restored
}

public struct LedgerEntry: Codable, Equatable {
    public var id: String
    public var mutation: Mutation
    public var status: LedgerEntryStatus
    public var ts: Date

    public init(
        id: String = UUID().uuidString,
        mutation: Mutation,
        status: LedgerEntryStatus = .pending,
        ts: Date = Date()
    ) {
        self.id = id
        self.mutation = mutation
        self.status = status
        self.ts = ts
    }
}

public struct RestoreLedger: Codable, Equatable {
    public var entries: [LedgerEntry]

    public init(entries: [LedgerEntry] = []) {
        self.entries = entries
    }

    public mutating func append(_ mutation: Mutation, status: LedgerEntryStatus = .pending) -> String {
        let entry = LedgerEntry(mutation: mutation, status: status)
        entries.append(entry)
        return entry.id
    }

    public mutating func markApplied(_ id: String) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].status = .applied
        }
    }

    public mutating func markRestored(_ id: String) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].status = .restored
        }
    }

    public var pendingOrApplied: [LedgerEntry] {
        entries.filter { $0.status == .pending || $0.status == .applied }
    }
}
