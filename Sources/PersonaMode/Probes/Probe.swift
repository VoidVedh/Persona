import Foundation

/// A runtime `--probe <name>` mode. Probes print JSON to stdout (and to `--out <file>` when given)
/// and return a process exit code. They run on the main thread.
@MainActor
public protocol Probe {
    static func run(args: [String]) -> Int32
}

/// Shared argument parsing + JSON output for probes.
public enum ProbeIO {
    public static func value(of flag: String, in args: [String]) -> String? {
        guard let idx = args.firstIndex(of: flag), idx + 1 < args.count else { return nil }
        return args[idx + 1]
    }

    public static func string(of flag: String, in args: [String]) -> String? {
        value(of: flag, in: args)
    }

    public static func double(of flag: String, in args: [String], default value: Double) -> Double {
        if let raw = Self.value(of: flag, in: args), let parsed = Double(raw) { return parsed }
        return value
    }

    public static func int(of flag: String, in args: [String], default value: Int) -> Int {
        if let raw = Self.value(of: flag, in: args), let parsed = Int(raw) { return parsed }
        return value
    }

    /// Serialises `object` (sorted keys, pretty) to stdout and optionally `--out`.
    @discardableResult
    public static func emit(_ object: Any, args: [String]) -> Int32 {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            fputs("Error: probe result is not valid JSON\n", stderr)
            return 1
        }
        print(text)
        if let path = value(of: "--out", in: args) {
            do {
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch {
                fputs("Error writing to \(path): \(error.localizedDescription)\n", stderr)
                return 1
            }
        }
        return 0
    }
}
