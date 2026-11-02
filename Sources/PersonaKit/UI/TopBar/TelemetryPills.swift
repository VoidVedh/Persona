import PersonaCore
import SwiftUI

public struct TelemetryPills: View {
    @ObservedObject var appState = AppState.shared

    public init() {}

    public var body: some View {
        let t = appState.telemetry

        HStack(spacing: 6) {
            // CPU Pill
            let cpuSev = PillSeverity.forUsage(t.cpu)
            pillView(
                icon: "cpu",
                text: "\(Int(t.cpu))%",
                severity: cpuSev,
                id: "topbar.cpu"
            )

            // RAM Pill
            let ramSev = PillSeverity.forUsage(t.ram)
            pillView(
                icon: "memorychip",
                text: "\(Int(t.ram))%",
                severity: ramSev,
                id: "topbar.ram"
            )

            // Battery Pill (hidden if desktop Mac)
            if t.battery.hasBattery {
                let batSev = PillSeverity.forBattery(percent: t.battery.percent, charging: t.battery.isCharging)
                let icon = t.battery.isCharging ? "battery.100.bolt" : "battery.75"
                pillView(
                    icon: icon,
                    text: "\(Int(t.battery.percent))%",
                    severity: batSev,
                    id: "topbar.battery"
                )
            }

            // Wi-Fi Pill
            let wifiIcon = t.wifi.isConnected ? (t.wifi.isWiFi ? "wifi" : "network") : "wifi.slash"
            let wifiColor: PillSeverity = t.wifi.isConnected ? .normal : .alert
            pillView(
                icon: wifiIcon,
                text: t.wifi.isConnected ? "\(t.wifi.bars)b" : "OFF",
                severity: wifiColor,
                id: "topbar.wifi"
            )

            // Volume Pill
            let volIcon = t.volume.isMuted ? "speaker.slash" : "speaker.wave.2"
            pillView(
                icon: volIcon,
                text: t.volume.isMuted ? "MUTE" : "\(t.volume.percent)%",
                severity: .normal,
                id: "topbar.volume"
            )
        }
    }

    private func pillView(icon: String, text: String, severity: PillSeverity, id: String) -> some View {
        let color = ThemeColors.tint(for: severity)

        return ZStack {
            SkewedPill()
                .fill(ThemeColors.midnight.opacity(0.85))
                .overlay(
                    SkewedPill()
                        .stroke(color.opacity(0.6), lineWidth: 1)
                )

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(text)
                    .font(Fonts.body(12, bold: true))
                    .foregroundColor(ThemeColors.white)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 22)
        .accessibilityIdentifier(id)
    }
}
