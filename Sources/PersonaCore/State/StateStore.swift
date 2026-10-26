import Foundation

public final class StateStore {
    public let supportDir: URL
    private let stateFileURL: URL
    private let prevFileURL: URL
    private let tmpFileURL: URL

    public static func defaultDir() -> URL {
        if let env = ProcessInfo.processInfo.environment["PERSONA_SUPPORT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PersonaMode", isDirectory: true)
    }

    public init(supportDir: URL = StateStore.defaultDir()) {
        self.supportDir = supportDir
        self.stateFileURL = supportDir.appendingPathComponent("state.json")
        self.prevFileURL = supportDir.appendingPathComponent("state.json.prev")
        self.tmpFileURL = supportDir.appendingPathComponent("state.json.tmp")

        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        let path = supportDir.path
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        } else {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path)
        }
    }

    public func save(_ state: StateFile) throws {
        ensureDirectoryExists()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(state)

        // 1. Write to state.json.tmp with 0600 mode
        let tmpPath = tmpFileURL.path
        let fd = open(tmpPath, O_WRONLY | O_CREAT | O_TRUNC, 0o600)
        guard fd >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let writeSuccess: Bool = data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress else { return true }
            var totalWritten = 0
            while totalWritten < data.count {
                let bytesWritten = write(fd, ptr + totalWritten, data.count - totalWritten)
                if bytesWritten < 0 { return false }
                totalWritten += bytesWritten
            }
            return true
        }

        if !writeSuccess {
            close(fd)
            unlink(tmpPath)
            throw POSIXError(.EIO)
        }

        // fsync the file
        fsync(fd)
        close(fd)

        // 2. If state.json currently exists, copy to state.json.prev
        let statePath = stateFileURL.path
        let prevPath = prevFileURL.path
        if FileManager.default.fileExists(atPath: statePath) {
            _ = unlink(prevPath)
            _ = link(statePath, prevPath) // hardlink or copy
            if !FileManager.default.fileExists(atPath: prevPath) {
                try? FileManager.default.copyItem(atPath: statePath, toPath: prevPath)
            }
        }

        // 3. Atomic rename tmp -> state.json
        if rename(tmpPath, statePath) != 0 {
            unlink(tmpPath)
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        // 4. fsync the directory
        let dirFd = open(supportDir.path, O_RDONLY)
        if dirFd >= 0 {
            fsync(dirFd)
            close(dirFd)
        }
    }

    public func load() -> StateFile? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try primary state.json
        if let data = try? Data(contentsOf: stateFileURL) {
            if let state = try? decoder.decode(StateFile.self, from: data) {
                return state
            }
        }

        // Fallback to state.json.prev
        if let prevData = try? Data(contentsOf: prevFileURL) {
            if let state = try? decoder.decode(StateFile.self, from: prevData) {
                return state
            }
        }

        return nil
    }

    public func delete() {
        try? FileManager.default.removeItem(at: stateFileURL)
        try? FileManager.default.removeItem(at: prevFileURL)
        try? FileManager.default.removeItem(at: tmpFileURL)
    }

    public var stateFileExists: Bool {
        FileManager.default.fileExists(atPath: stateFileURL.path)
    }
}
