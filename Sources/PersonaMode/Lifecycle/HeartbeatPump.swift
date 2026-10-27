import Foundation

public final class HeartbeatPump {
    public let supportDir: URL
    private let heartbeatURL: URL
    private var mainTimer: Timer?
    private var backgroundTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dev.persona.mode.heartbeat", qos: .utility)
    private var lastMainPong: Date = Date()
    private let lock = NSLock()

    public init(supportDir: URL) {
        self.supportDir = supportDir
        self.heartbeatURL = supportDir.appendingPathComponent("heartbeat")
    }

    public func start() {
        // Main thread pong timer
        lastMainPong = Date()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.lock.lock()
            self?.lastMainPong = Date()
            self?.lock.unlock()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.mainTimer = timer

        // Background timer to touch heartbeat file
        let bg = DispatchSource.makeTimerSource(queue: queue)
        bg.schedule(deadline: .now(), repeating: .seconds(1))
        bg.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            let timeSincePong = Date().timeIntervalSince(self.lastMainPong)
            self.lock.unlock()

            if timeSincePong < 8.0 {
                self.touchHeartbeat()
            }
        }
        bg.resume()
        self.backgroundTimer = bg
    }

    private func touchHeartbeat() {
        let path = heartbeatURL.path
        if !FileManager.default.fileExists(atPath: path) {
            let data = "\(ProcessInfo.processInfo.processIdentifier)\n".data(using: .utf8)
            FileManager.default.createFile(atPath: path, contents: data, attributes: [
                .posixPermissions: 0o600
            ])
        } else {
            let fd = open(path, O_WRONLY, 0o600)
            if fd >= 0 {
                futimens(fd, nil)
                close(fd)
            }
        }
    }

    public func stop() {
        mainTimer?.invalidate()
        mainTimer = nil
        backgroundTimer?.cancel()
        backgroundTimer = nil
        try? FileManager.default.removeItem(at: heartbeatURL)
    }

    deinit {
        stop()
    }
}
