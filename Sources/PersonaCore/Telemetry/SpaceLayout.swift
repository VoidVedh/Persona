import Foundation

/// One workspace indicator pill.
public struct SpacePill: Equatable {
    public let index: Int
    public let isActive: Bool
    public init(index: Int, isActive: Bool) {
        self.index = index
        self.isActive = isActive
    }
}

/// Parsed state of the macOS Spaces for the display hosting the bar.
public struct SpaceSnapshot: Equatable {
    /// False when the private CGS symbols are missing or returned nothing.
    public var available: Bool
    /// Number of ordinary desktop Spaces (full-screen app Spaces are excluded).
    public var count: Int
    /// 1-based index of the active desktop Space; 0 when the active Space is a full-screen app.
    public var activeIndex: Int

    public init(available: Bool, count: Int, activeIndex: Int) {
        self.available = available
        self.count = count
        self.activeIndex = activeIndex
    }

    public static let unavailable = SpaceSnapshot(available: false, count: 1, activeIndex: 1)
}

public enum SpaceLayout {
    public static let maxPills = 5

    /// Parses the array returned by `CGSCopyManagedDisplaySpaces`.
    ///
    /// Picks the display whose `Spaces` contain `activeSpaceID` (else the first display), keeps only
    /// ordinary desktop Spaces (`type == 0`; full-screen Spaces are `type == 4`), and locates the active one.
    public static func parse(displays: [[String: Any]], activeSpaceID: UInt64?) -> SpaceSnapshot {
        guard !displays.isEmpty else { return .unavailable }

        func id(of space: [String: Any]) -> UInt64? {
            (space["ManagedSpaceID"] as? NSNumber)?.uint64Value ?? (space["id64"] as? NSNumber)?.uint64Value
        }
        func spaces(of display: [String: Any]) -> [[String: Any]] {
            (display["Spaces"] as? [[String: Any]]) ?? []
        }

        var chosen = displays[0]
        if let active = activeSpaceID {
            for display in displays where spaces(of: display).contains(where: { id(of: $0) == active }) {
                chosen = display
                break
            }
        }

        let desktops = spaces(of: chosen).filter { (($0["type"] as? NSNumber)?.intValue ?? 0) == 0 }
        guard !desktops.isEmpty else { return .unavailable }

        var activeID = activeSpaceID
        if activeID == nil, let current = chosen["Current Space"] as? [String: Any] { activeID = id(of: current) }
        var activeIndex = 0
        if let activeID, let idx = desktops.firstIndex(where: { id(of: $0) == activeID }) {
            activeIndex = idx + 1
        }
        return SpaceSnapshot(available: true, count: desktops.count, activeIndex: activeIndex)
    }

    /// Pills to render. When Spaces are unavailable: a single active pill "1" (sane fallback, R3).
    public static func pills(for snapshot: SpaceSnapshot) -> [SpacePill] {
        guard snapshot.available else { return [SpacePill(index: 1, isActive: true)] }
        let n = min(maxPills, max(1, snapshot.count))
        return (1...n).map { SpacePill(index: $0, isActive: $0 == snapshot.activeIndex) }
    }

    /// Key code for "Control+N" Space shortcuts (digits 1–5 are 18, 19, 20, 21, 23).
    public static func keyCode(forDesktop n: Int) -> Int? {
        switch n {
        case 1: return 18
        case 2: return 19
        case 3: return 20
        case 4: return 21
        case 5: return 23
        default: return nil
        }
    }

    /// `AppleSymbolicHotKeys` ids for "Switch to Desktop 1…5" are 118…122.
    public static func symbolicHotKeyID(forDesktop n: Int) -> Int? {
        (1...5).contains(n) ? 117 + n : nil
    }

    /// Whether the "Switch to Desktop n" shortcut is enabled in a decoded `AppleSymbolicHotKeys` dictionary.
    public static func isShortcutEnabled(desktop n: Int, symbolicHotKeys: [String: Any]?) -> Bool {
        guard let hotKeyID = symbolicHotKeyID(forDesktop: n),
              let entry = symbolicHotKeys?[String(hotKeyID)] as? [String: Any] else { return false }
        if let b = entry["enabled"] as? Bool { return b }
        if let n = entry["enabled"] as? NSNumber { return n.boolValue }
        return false
    }
}
