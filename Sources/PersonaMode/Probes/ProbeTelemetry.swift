import Foundation
import PersonaKit

public enum ProbeTelemetry: Probe {
    public static func run(args: [String]) -> Int32 {
        let sampleCount = ProbeIO.int(of: "--samples", in: args, default: 3)
        let store = TelemetryStore.shared

        var samples: [[String: Any]] = []
        for i in 0..<sampleCount {
            if i > 0 {
                Thread.sleep(forTimeInterval: 1.0)
            }
            let s = store.sampleOnce()
            var entry: [String: Any] = [
                "cpu": s.cpu,
                "ram": s.ram,
                "wifi": [
                    "connected": s.wifi.isConnected,
                    "bars": s.wifi.bars
                ],
                "volume": [
                    "percent": s.volume.percent,
                    "muted": s.volume.isMuted
                ]
            ]
            if s.battery.hasBattery {
                entry["batteryPercent"] = s.battery.percent
                entry["charging"] = s.battery.isCharging
            }
            samples.append(entry)
        }

        return ProbeIO.emit(["samples": samples], args: args)
    }
}
