import AppKit
import Foundation
import PersonaCore

@MainActor
public final class NowPlayingService {
    public static let shared = NowPlayingService()

    private var observers: [NSObjectProtocol] = []
    private var isRunning = false

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let center = DistributedNotificationCenter.default()
        for name in NowPlayingParser.notificationNames {
            let obs = center.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] notif in
                Task { @MainActor in
                    self?.handleNotification(notif)
                }
            }
            observers.append(obs)
        }

        seedInitialState()
    }

    public func stop() {
        for obs in observers {
            DistributedNotificationCenter.default().removeObserver(obs)
        }
        observers.removeAll()
        isRunning = false
    }

    private func handleNotification(_ notif: Notification) {
        if let np = NowPlayingParser.parse(notification: notif.name.rawValue, userInfo: notif.userInfo) {
            if np.state == .stopped {
                AppState.shared.nowPlaying = nil
            } else {
                AppState.shared.nowPlaying = np
            }
        }
    }

    private func seedInitialState() {
        // Only run AppleScript query if the player is already running!
        let players = [
            ("music", "com.apple.Music"),
            ("spotify", "com.spotify.client")
        ]

        for (source, bundleId) in players {
            let running = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).isEmpty
            if running {
                let script = NowPlayingParser.seedScript(bundleID: bundleId)
                DispatchQueue.global(qos: .utility).async {
                    var error: NSDictionary?
                    if let scriptObj = NSAppleScript(source: script) {
                        let result = scriptObj.executeAndReturnError(&error)
                        if error == nil, let text = result.stringValue {
                            DispatchQueue.main.async {
                                if let parsed = NowPlayingParser.parseSeed(source: source, output: text) {
                                    if parsed.state != .stopped {
                                        AppState.shared.nowPlaying = parsed
                                    }
                                }
                            }
                            return // Seeded from first running player
                        }
                    }
                }
            }
        }
    }
}
