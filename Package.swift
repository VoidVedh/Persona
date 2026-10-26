// swift-tools-version:6.0
import PackageDescription

let swift5: [SwiftSetting] = [
    .swiftLanguageMode(.v5)
]

let package = Package(
    name: "Persona",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PersonaMode", targets: ["PersonaMode"]),
        .executable(name: "persona-selftest", targets: ["PersonaSelfTest"])
    ],
    targets: [
        .target(
            name: "PersonaCore",
            swiftSettings: swift5
        ),
        .executableTarget(
            name: "PersonaMode",
            dependencies: ["PersonaCore"],
            swiftSettings: swift5
        ),
        .executableTarget(
            name: "PersonaSelfTest",
            dependencies: ["PersonaCore"],
            swiftSettings: swift5
        )
    ]
)
