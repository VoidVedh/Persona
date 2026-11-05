import Foundation

/// Pure inputs for deciding whether ambient HUD animations should enter Calm Mode (§11.1).
public struct CalmInputs: Equatable {
    public var lowPowerMode: Bool
    public var hasBattery: Bool
    public var isCharging: Bool
    public var batteryPercent: Int
    public var previouslyBatteryLatched: Bool
    public var screensSleeping: Bool
    public var fullscreenAppFrontmost: Bool
    public var thermalSeriousOrCritical: Bool
    public var ambientAnimationEnabled: Bool
    public var calmOnBatteryEnabled: Bool
    public var envHudAnimationDisabled: Bool

    public init(
        lowPowerMode: Bool = false,
        hasBattery: Bool = false,
        isCharging: Bool = true,
        batteryPercent: Int = 100,
        previouslyBatteryLatched: Bool = false,
        screensSleeping: Bool = false,
        fullscreenAppFrontmost: Bool = false,
        thermalSeriousOrCritical: Bool = false,
        ambientAnimationEnabled: Bool = true,
        calmOnBatteryEnabled: Bool = true,
        envHudAnimationDisabled: Bool = false
    ) {
        self.lowPowerMode = lowPowerMode
        self.hasBattery = hasBattery
        self.isCharging = isCharging
        self.batteryPercent = batteryPercent
        self.previouslyBatteryLatched = previouslyBatteryLatched
        self.screensSleeping = screensSleeping
        self.fullscreenAppFrontmost = fullscreenAppFrontmost
        self.thermalSeriousOrCritical = thermalSeriousOrCritical
        self.ambientAnimationEnabled = ambientAnimationEnabled
        self.calmOnBatteryEnabled = calmOnBatteryEnabled
        self.envHudAnimationDisabled = envHudAnimationDisabled
    }
}

public struct CalmDecision: Equatable {
    public let calm: Bool
    public let batteryLatched: Bool

    public init(calm: Bool, batteryLatched: Bool) {
        self.calm = calm
        self.batteryLatched = batteryLatched
    }
}

/// Pure policy engine for Calm Mode (`html[data-calm="1"]` and `AppState.ambientPaused`).
public enum CalmPolicy {
    /// Evaluates whether ambient animation should be paused (`calm == true`) with 20%↔25% battery hysteresis.
    public static func decide(_ inputs: CalmInputs) -> CalmDecision {
        let batteryLatched: Bool
        if inputs.calmOnBatteryEnabled && inputs.hasBattery && !inputs.isCharging {
            if inputs.batteryPercent < 20 {
                batteryLatched = true
            } else if inputs.batteryPercent >= 25 {
                batteryLatched = false
            } else {
                batteryLatched = inputs.previouslyBatteryLatched
            }
        } else {
            batteryLatched = false
        }

        let calm = !inputs.ambientAnimationEnabled
            || inputs.envHudAnimationDisabled
            || inputs.lowPowerMode
            || batteryLatched
            || inputs.screensSleeping
            || inputs.fullscreenAppFrontmost
            || inputs.thermalSeriousOrCritical

        return CalmDecision(calm: calm, batteryLatched: batteryLatched)
    }
}
