import Foundation
import PersonaCore

@MainActor
public final class TelemetryStore {
    public static let shared = TelemetryStore()

    private let cpuSampler = CPUSampler()
    private let memSampler = MemorySampler()
    private let batSampler = BatterySampler()
    private let wifiSampler = WiFiSampler()
    private let volSampler = VolumeSampler()

    private var timer: DispatchSourceTimer?
    private var isRunning = false

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let t = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global(qos: .utility))
        t.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(200))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            let cpu = self.cpuSampler.sample()
            let ram = self.memSampler.sample()
            let bat = self.batSampler.sample()
            let wifi = self.wifiSampler.sample()
            let vol = self.volSampler.sample()

            let roundedCpu = (cpu * 10).rounded() / 10
            let roundedRam = (ram * 10).rounded() / 10
            let snapshot = TelemetrySnapshot(
                cpu: roundedCpu,
                ram: roundedRam,
                battery: bat,
                wifi: wifi,
                volume: vol
            )

            DispatchQueue.main.async {
                if AppState.shared.telemetry != snapshot {
                    AppState.shared.telemetry = snapshot
                }
                AppState.shared.updateDarkHourPhase()
            }
        }
        t.resume()
        self.timer = t
    }

    public func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    /// Single one-shot sample for probes
    public func sampleOnce() -> TelemetrySnapshot {
        let cpu = cpuSampler.sample()
        let ram = memSampler.sample()
        let bat = batSampler.sample()
        let wifi = wifiSampler.sample()
        let vol = volSampler.sample()

        return TelemetrySnapshot(
            cpu: cpu,
            ram: ram,
            battery: bat,
            wifi: wifi,
            volume: vol
        )
    }
}
