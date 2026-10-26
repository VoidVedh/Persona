import Foundation
import PersonaCore

let args = CommandLine.arguments

if args.count >= 3 && args[1] == "--probe" {
    let probeName = args[2]
    let remainingArgs = Array(args.dropFirst(3))

    switch probeName {
    case "snapshot":
        let code = ProbeSnapshot.run(args: remainingArgs)
        exit(code)
    default:
        fputs("Unknown probe: \(probeName)\n", stderr)
        exit(1)
    }
}

print("PersonaMode \(PersonaCore.version)")
