import Foundation

public final class Harness {
    public private(set) var passes: Int = 0
    public private(set) var failures: Int = 0
    private var currentSuite: String = ""

    public init() {}

    public func suite(_ name: String, _ body: () throws -> Void) {
        let prevSuite = currentSuite
        currentSuite = name
        defer { currentSuite = prevSuite }
        do {
            try body()
        } catch {
            fail("Unhandled exception in suite \(name): \(error)")
        }
    }

    public func test(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            fail("Unhandled exception in test \(name): \(error)")
        }
    }

    public func pass(_ name: String) {
        passes += 1
        let prefix = currentSuite.isEmpty ? "" : "\(currentSuite)/"
        print("PASS \(prefix)\(name)")
    }

    public func fail(_ msg: String, file: StaticString = #fileID, line: UInt = #line) {
        failures += 1
        let prefix = currentSuite.isEmpty ? "" : "\(currentSuite)/"
        print("FAIL \(prefix)\(msg) (\(file):\(line))")
    }

    public func expect(_ cond: @autoclosure () -> Bool, _ msg: String, file: StaticString = #fileID, line: UInt = #line) {
        if cond() {
            pass(msg)
        } else {
            fail(msg, file: file, line: line)
        }
    }

    public func expectEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: StaticString = #fileID, line: UInt = #line) {
        if a == b {
            pass(msg.isEmpty ? "expected \(a) == \(b)" : msg)
        } else {
            let detail = msg.isEmpty ? "expected \(a) == \(b)" : "\(msg) (expected: \(b), got: \(a))"
            fail(detail, file: file, line: line)
        }
    }

    public func expectThrows<T>(_ msg: String = "expected error", file: StaticString = #fileID, line: UInt = #line, _ body: () throws -> T) {
        do {
            _ = try body()
            fail("\(msg): no error was thrown", file: file, line: line)
        } catch {
            pass(msg)
        }
    }
}
