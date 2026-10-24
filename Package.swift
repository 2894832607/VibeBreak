// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "VibeBreak",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "VibeBreakCore", targets: ["VibeBreakCore"]),
        .executable(name: "VibeBreak", targets: ["VibeBreakApp"]),
        .executable(
            name: "vibebreak-bridge-emit",
            targets: ["VibeBreakBridgeEmit"]
        ),
    ],
    targets: [
        .target(
            name: "VibeBreakCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "VibeBreakApp",
            dependencies: ["VibeBreakCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .executableTarget(
            name: "VibeBreakBridgeEmit",
            dependencies: ["VibeBreakCore"]
        ),
        .testTarget(
            name: "VibeBreakCoreTests",
            dependencies: ["VibeBreakCore"],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .testTarget(
            name: "VibeBreakAppTests",
            dependencies: ["VibeBreakApp"]
        ),
    ]
)
