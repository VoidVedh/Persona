import Foundation
import IOKit.ps

public struct BatteryState: Equatable {
    public var hasBattery: Bool
    public var percent: Double
    public var isCharging: Bool

    public init(hasBattery: Bool, percent: Double, isCharging: Bool) {
        self.hasBattery = hasBattery
        self.percent = percent
        self.isCharging = isCharging
    }
}

public final class BatterySampler {
    public init() {}

    public func sample() -> BatteryState {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              !list.isEmpty else {
            return BatteryState(hasBattery: false, percent: 100, isCharging: false)
        }

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(blob, ps)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }

            guard let isPresent = desc[kIOPSIsPresentKey] as? Bool, isPresent else {
                continue
            }

            let curCap = desc[kIOPSCurrentCapacityKey] as? Double ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey] as? Double ?? 100
            let percent = maxCap > 0 ? min(100.0, max(0.0, (curCap / maxCap) * 100.0)) : 100.0
            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

            return BatteryState(hasBattery: true, percent: percent, isCharging: isCharging)
        }

        return BatteryState(hasBattery: false, percent: 100, isCharging: false)
    }
}
