import CoreWLAN
import Foundation
import Network
import PersonaCore

public struct WiFiState: Equatable {
    public var isConnected: Bool
    public var isWiFi: Bool
    public var bars: Int

    public init(isConnected: Bool, isWiFi: Bool, bars: Int) {
        self.isConnected = isConnected
        self.isWiFi = isWiFi
        self.bars = bars
    }
}

public final class WiFiSampler {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.persona.mode.wifi", qos: .utility)
    private var isConnected = false
    private var isWiFi = false
    private var cachedInterface: CWInterface?

    public init() {
        cachedInterface = CWWiFiClient.shared().interface()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
            self?.isWiFi = path.usesInterfaceType(.wifi)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    public func sample() -> WiFiState {
        let connected = isConnected
        let wifi = isWiFi

        var bars = 0
        if connected {
            if wifi {
                if cachedInterface == nil {
                    cachedInterface = CWWiFiClient.shared().interface()
                }
                let rssi = cachedInterface?.rssiValue() ?? 0
                bars = WiFiMath.bars(rssi: rssi, connected: true)
                if bars == 0 { bars = 3 } // Default fallback if connected but rssi is 0
            } else {
                // Wired ethernet / other satisfied connection gets full bars
                bars = 4
            }
        }

        return WiFiState(isConnected: connected, isWiFi: wifi, bars: bars)
    }
}
