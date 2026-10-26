import Foundation

public protocol Probe {
    static func run(args: [String]) -> Int32
}
