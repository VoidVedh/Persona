import Foundation

public enum LifecyclePhase: String, Codable, Equatable {
    case snapshotted
    case armed
    case active
    case restoring
    case restored
    case degraded
}

public struct StateFile: Codable, Equatable {
    public var schemaVersion: Int
    public var sessionId: String
    public var active: Bool
    public var appPid: Int32
    public var createdAt: Date
    public var macOS: String
    public var wallpaperMode: WallpaperMode
    public var snapshot: SystemStateSnapshot
    public var ledger: RestoreLedger
    public var phase: LifecyclePhase

    public init(
        schemaVersion: Int = 1,
        sessionId: String = UUID().uuidString,
        active: Bool = true,
        appPid: Int32 = ProcessInfo.processInfo.processIdentifier,
        createdAt: Date = Date(),
        macOS: String = ProcessInfo.processInfo.operatingSystemVersionString,
        wallpaperMode: WallpaperMode = .overlay,
        snapshot: SystemStateSnapshot,
        ledger: RestoreLedger = RestoreLedger(),
        phase: LifecyclePhase = .snapshotted
    ) {
        self.schemaVersion = schemaVersion
        self.sessionId = sessionId
        self.active = active
        self.appPid = appPid
        self.createdAt = createdAt
        self.macOS = macOS
        self.wallpaperMode = wallpaperMode
        self.snapshot = snapshot
        self.ledger = ledger
        self.phase = phase
    }
}
