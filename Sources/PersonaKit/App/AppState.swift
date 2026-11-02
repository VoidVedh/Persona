import AppKit
import Foundation
import PersonaCore

public struct TelemetrySnapshot: Equatable {
    public var cpu: Double
    public var ram: Double
    public var battery: BatteryState
    public var wifi: WiFiState
    public var volume: VolumeState

    public init(
        cpu: Double = 0.0,
        ram: Double = 0.0,
        battery: BatteryState = BatteryState(hasBattery: false, percent: 100, isCharging: false),
        wifi: WiFiState = WiFiState(isConnected: true, isWiFi: true, bars: 4),
        volume: VolumeState = VolumeState(percent: 50, isMuted: false)
    ) {
        self.cpu = cpu
        self.ram = ram
        self.battery = battery
        self.wifi = wifi
        self.volume = volume
    }
}

/// Central observable state for the Persona Desktop Environment.
@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var focusedApp: String = "DESKTOP"
    @Published public var focusedTitle: String = ""
    @Published public var spaceSnapshot: SpaceSnapshot = .unavailable
    @Published public var telemetry: TelemetrySnapshot = TelemetrySnapshot()
    @Published public var nowPlaying: NowPlaying? = nil
    @Published public var darkHourPhase: DarkHourPhase = .daytime
    @Published public var forcedDarkHour: Bool? = nil
    @Published public var ambientPaused: Bool = false
    @Published public var hintMessage: String? = nil

    public init() {
        updateDarkHourPhase()
    }

    public func updateDarkHourPhase() {
        let newPhase = DarkHourPhase.phase(for: Date(), calendar: .current, force: forcedDarkHour)
        if self.darkHourPhase != newPhase {
            self.darkHourPhase = newPhase
        }
    }

    public func toggleDarkHour() {
        if forcedDarkHour == true {
            forcedDarkHour = nil
        } else {
            forcedDarkHour = true
        }
        updateDarkHourPhase()
    }
}
