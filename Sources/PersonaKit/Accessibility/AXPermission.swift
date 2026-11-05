import ApplicationServices
import AppKit
import Foundation

/// Manages macOS Accessibility API permission state and requests.
public final class AXPermission {
    public static let shared = AXPermission()

    public static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    private var pollTimer: DispatchSourceTimer?
    private var lastKnownState: Bool = false

    public init() {
        self.lastKnownState = isTrusted
    }

    /// Checks whether the current process is trusted for Accessibility API access.
    public var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Queries or requests Accessibility trust.
    ///
    /// - Parameter prompt: If `true`, prompts macOS to display the system trust dialog.
    ///   Defaults to `false` so headless operations, probes, and tests never block.
    /// - Returns: `true` if trusted at the time of call.
    @discardableResult
    public func request(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): prompt] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        lastKnownState = trusted
        return trusted
    }

    /// Opens System Settings directly to the Accessibility privacy pane.
    public func openSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
    }

    /// Polls for accessibility trust changes on a background utility queue.
    public func startPolling(
        interval: TimeInterval = 1.0,
        onChange: @escaping @Sendable (Bool) -> Void
    ) {
        stopPolling()

        let timer = DispatchSource.makeTimerSource(flags: [], queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            let current = self.isTrusted
            if current != self.lastKnownState {
                self.lastKnownState = current
                onChange(current)
            }
        }
        timer.resume()
        self.pollTimer = timer
    }

    public func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }
}
