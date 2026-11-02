import Foundation
import PersonaCore

public enum TelemetrySuite {
    public static func run(_ t: Harness) {
        t.suite("telemetry") {
            // CPU Math tests
            // Format: [user, system, idle, nice] per core
            // Test 1: 0% CPU (only idle ticks increased)
            let prevIdle: [UInt32] = [100, 50, 1000, 0]
            let curIdle: [UInt32]  = [100, 50, 2000, 0]
            let usageIdle = CPUMath.usage(prev: prevIdle, cur: curIdle)
            t.expectEqual(usageIdle, 0.0, "0% CPU when only idle counter increments")

            // Test 2: 100% CPU (only user/system ticks increased)
            let prevBusy: [UInt32] = [100, 50, 1000, 0]
            let curBusy: [UInt32]  = [600, 550, 1000, 0]
            let usageBusy = CPUMath.usage(prev: prevBusy, cur: curBusy)
            t.expectEqual(usageBusy, 100.0, "100% CPU when only busy counters increment")

            // Test 3: 50% CPU
            let prevHalf: [UInt32] = [0, 0, 0, 0]
            let curHalf: [UInt32]  = [50, 0, 50, 0]
            let usageHalf = CPUMath.usage(prev: prevHalf, cur: curHalf)
            t.expectEqual(usageHalf, 50.0, "50% CPU usage calculation")

            // Test 4: UInt32 wrapping
            let prevWrap: [UInt32] = [UInt32.max - 50, 0, 0, 0]
            let curWrap: [UInt32]  = [50, 0, 100, 0]
            // user went from max-50 to 50 => delta is 101 ticks
            // idle went from 0 to 100 => delta is 100 ticks
            let usageWrap = CPUMath.usage(prev: prevWrap, cur: curWrap)
            t.expect(usageWrap > 45.0 && usageWrap < 55.0, "CPU math handles UInt32 counter wrap correctly")

            // Memory Math tests
            // 8GB used out of 16GB => 50%
            let usedHalf = MemoryMath.usedPercent(active: 4, wired: 2, compressed: 2, total: 16)
            t.expectEqual(usedHalf, 50.0, "50% RAM used")

            let usedNone = MemoryMath.usedPercent(active: 0, wired: 0, compressed: 0, total: 16)
            t.expectEqual(usedNone, 0.0, "0% RAM used")

            // Wi-Fi Math tests
            t.expectEqual(WiFiMath.bars(rssi: -45, connected: true), 4, "-45 dBm is 4 bars")
            t.expectEqual(WiFiMath.bars(rssi: -55, connected: true), 3, "-55 dBm is 3 bars")
            t.expectEqual(WiFiMath.bars(rssi: -65, connected: true), 2, "-65 dBm is 2 bars")
            t.expectEqual(WiFiMath.bars(rssi: -75, connected: true), 1, "-75 dBm is 1 bar")
            t.expectEqual(WiFiMath.bars(rssi: -45, connected: false), 0, "disconnected yields 0 bars")

            // Volume Math tests
            t.expectEqual(VolumeMath.percent(scalar: 0.75), 75, "0.75 scalar is 75%")
            t.expectEqual(VolumeMath.percent(scalar: 0.0), 0, "0.0 scalar is 0%")
            t.expectEqual(VolumeMath.percent(scalar: 1.0), 100, "1.0 scalar is 100%")
            t.expectEqual(VolumeMath.percent(scalar: 1.2), 100, "scalar clamped to 100%")
        }
    }
}
