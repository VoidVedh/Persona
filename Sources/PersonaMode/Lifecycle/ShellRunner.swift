import Foundation

public enum ShellRunner {
    public static func run(
        _ exe: String,
        _ args: [String],
        timeout: TimeInterval = 3
    ) -> (status: Int32, out: String, err: String, timedOut: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return (-1, "", error.localizedDescription, false)
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            semaphore.signal()
        }

        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        if timeoutResult == .timedOut {
            process.terminate()
            // Read whatever was buffered
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let outStr = String(data: outData, encoding: .utf8) ?? ""
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            return (-1, outStr, errStr, true)
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8) ?? ""
        let errStr = String(data: errData, encoding: .utf8) ?? ""

        return (process.terminationStatus, outStr, errStr, false)
    }

    public static func runAppleScript(
        _ script: String,
        timeout: TimeInterval = 3
    ) -> (status: Int32, out: String, err: String, timedOut: Bool) {
        return run("/usr/bin/osascript", ["-e", script], timeout: timeout)
    }
}
