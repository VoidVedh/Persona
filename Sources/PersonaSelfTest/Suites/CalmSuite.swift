import Foundation
import PersonaCore

enum CalmSuite {
    static func run(_ h: Harness) {
        h.suite("CalmPolicy") {
            let baseline = CalmInputs(
                lowPowerMode: false,
                hasBattery: true,
                isCharging: true,
                batteryPercent: 100,
                previouslyBatteryLatched: false,
                screensSleeping: false,
                fullscreenAppFrontmost: false,
                thermalSeriousOrCritical: false,
                ambientAnimationEnabled: true,
                calmOnBatteryEnabled: true,
                envHudAnimationDisabled: false
            )
            let d0 = CalmPolicy.decide(baseline)
            h.expect(!d0.calm, "default AC healthy state is not calm")
            h.expect(!d0.batteryLatched, "default AC healthy state is not batteryLatched")

            // Single-trigger truth table
            var lpm = baseline
            lpm.lowPowerMode = true
            h.expect(CalmPolicy.decide(lpm).calm, "Low Power Mode triggers calm")

            var sleep = baseline
            sleep.screensSleeping = true
            h.expect(CalmPolicy.decide(sleep).calm, "screensSleeping triggers calm")

            var fs = baseline
            fs.fullscreenAppFrontmost = true
            h.expect(CalmPolicy.decide(fs).calm, "fullscreenAppFrontmost triggers calm")

            var thermal = baseline
            thermal.thermalSeriousOrCritical = true
            h.expect(CalmPolicy.decide(thermal).calm, "thermalSeriousOrCritical triggers calm")

            var cfgDisabled = baseline
            cfgDisabled.ambientAnimationEnabled = false
            h.expect(CalmPolicy.decide(cfgDisabled).calm, "ambientAnimationEnabled=false triggers calm")

            var envDisabled = baseline
            envDisabled.envHudAnimationDisabled = true
            h.expect(CalmPolicy.decide(envDisabled).calm, "envHudAnimationDisabled triggers calm")

            // Battery hysteresis 20% <-> 25% while unplugged
            var batt = baseline
            batt.isCharging = false
            batt.batteryPercent = 24
            batt.previouslyBatteryLatched = false
            let d24 = CalmPolicy.decide(batt)
            h.expect(!d24.calm && !d24.batteryLatched, "unplugged at 24% unlatched stays active")

            batt.batteryPercent = 20
            let d20 = CalmPolicy.decide(batt)
            h.expect(!d20.calm && !d20.batteryLatched, "unplugged at 20% unlatched stays active (< 20 triggers)")

            batt.batteryPercent = 19
            let d19 = CalmPolicy.decide(batt)
            h.expect(d19.calm && d19.batteryLatched, "unplugged at 19% latches battery calm")

            // Rising from 19% -> 22% stays latched until >= 25%
            batt.batteryPercent = 22
            batt.previouslyBatteryLatched = d19.batteryLatched
            let d22 = CalmPolicy.decide(batt)
            h.expect(d22.calm && d22.batteryLatched, "unplugged rising to 22% remains latched (hysteresis)")

            batt.batteryPercent = 24
            batt.previouslyBatteryLatched = d22.batteryLatched
            let d24Latched = CalmPolicy.decide(batt)
            h.expect(d24Latched.calm && d24Latched.batteryLatched, "unplugged at 24% when latched remains latched")

            batt.batteryPercent = 25
            batt.previouslyBatteryLatched = d24Latched.batteryLatched
            let d25 = CalmPolicy.decide(batt)
            h.expect(!d25.calm && !d25.batteryLatched, "unplugged reaching 25% clears battery latch")

            // Plugging into AC immediately clears battery latch even at 10%
            var pluggedLow = batt
            pluggedLow.isCharging = true
            pluggedLow.batteryPercent = 10
            pluggedLow.previouslyBatteryLatched = true
            let dPlugged = CalmPolicy.decide(pluggedLow)
            h.expect(!dPlugged.calm && !dPlugged.batteryLatched, "charging clears battery latch even at 10%")

            // calmOnBattery=false disables battery calm
            var ignoreBatt = batt
            ignoreBatt.isCharging = false
            ignoreBatt.batteryPercent = 5
            ignoreBatt.calmOnBatteryEnabled = false
            let dIgnoreBatt = CalmPolicy.decide(ignoreBatt)
            h.expect(!dIgnoreBatt.calm && !dIgnoreBatt.batteryLatched, "calmOnBatteryEnabled=false ignores low battery")
        }
    }
}
