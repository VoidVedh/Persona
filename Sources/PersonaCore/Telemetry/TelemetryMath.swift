import Foundation

/// Pure CPU/RAM/Wi-Fi maths so the samplers' numeric behaviour is selftested without Mach calls.
public enum CPUMath {
    /// Per-core tick layout: `[user, system, idle, nice] × cores` (Mach `CPU_STATE_*` order).
    public static let statesPerCore = 4

    /// Aggregate CPU usage (%) between two samples of cumulative per-core tick counters.
    /// Uses wrapping subtraction so `UInt32` counter wrap-around is handled; result clamped to 0…100.
    public static func usage(prev: [UInt32], cur: [UInt32]) -> Double {
        guard prev.count == cur.count, cur.count >= statesPerCore, cur.count % statesPerCore == 0 else { return 0 }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        var i = 0
        while i < cur.count {
            let user = UInt64(cur[i] &- prev[i])
            let system = UInt64(cur[i + 1] &- prev[i + 1])
            let idle = UInt64(cur[i + 2] &- prev[i + 2])
            let nice = UInt64(cur[i + 3] &- prev[i + 3])
            busy += user + system + nice
            total += user + system + nice + idle
            i += statesPerCore
        }
        guard total > 0 else { return 0 }
        return min(100, max(0, Double(busy) / Double(total) * 100))
    }
}

public enum MemoryMath {
    /// Activity-Monitor-style "used" percentage = (active + wired + compressed) / total, clamped 0…100.
    /// All quantities in the same unit (bytes or pages).
    public static func usedPercent(active: UInt64, wired: UInt64, compressed: UInt64, total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        let used = active &+ wired &+ compressed
        return min(100, max(0, Double(used) / Double(total) * 100))
    }
}

public enum WiFiMath {
    /// Maps RSSI (dBm) to 0…4 signal bars. `rssi == 0` means "unknown" (no association) ⇒ 0 bars.
    public static func bars(rssi: Int, connected: Bool) -> Int {
        guard connected, rssi != 0 else { return 0 }
        switch rssi {
        case (-50)...: return 4
        case (-60)...: return 3
        case (-70)...: return 2
        default: return 1
        }
    }
}

public enum VolumeMath {
    /// 0…1 scalar → whole percent, clamped.
    public static func percent(scalar: Double) -> Int {
        Int((min(1, max(0, scalar)) * 100).rounded())
    }
}
