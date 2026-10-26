import Foundation

public final class SessionLock {
    public let lockFileURL: URL
    private var fileDescriptor: Int32 = -1

    public init?(dir: URL) {
        self.lockFileURL = dir.appendingPathComponent("session.lock")

        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        }

        let fd = open(lockFileURL.path, O_RDWR | O_CREAT, 0o600)
        guard fd >= 0 else { return nil }

        // Attempt non-blocking exclusive lock
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return nil
        }

        self.fileDescriptor = fd

        // Truncate and write PID
        ftruncate(fd, 0)
        lseek(fd, 0, SEEK_SET)
        let pidStr = "\(ProcessInfo.processInfo.processIdentifier)\n"
        if let data = pidStr.data(using: .utf8) {
            data.withUnsafeBytes { buf in
                guard let base = buf.baseAddress else { return }
                _ = write(fd, base, data.count)
            }
        }
        fsync(fd)
    }

    public static func isHeldByOther(dir: URL) -> Bool {
        let lockURL = dir.appendingPathComponent("session.lock")
        guard FileManager.default.fileExists(atPath: lockURL.path) else {
            return false
        }

        let fd = open(lockURL.path, O_RDWR, 0o600)
        guard fd >= 0 else {
            // Cannot open read-write: likely locked/in use
            return true
        }
        defer { close(fd) }

        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            // Another process holds the lock
            return true
        }

        // We acquired the lock, so another process does not hold it
        flock(fd, LOCK_UN)
        return false
    }

    public func release() {
        guard fileDescriptor >= 0 else { return }
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
        fileDescriptor = -1
        _ = unlink(lockFileURL.path)
    }

    deinit {
        release()
    }
}
