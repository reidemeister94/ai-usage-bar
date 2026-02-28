// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIUsageBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "AIUsageBar", targets: ["AIUsageBar"])
    ],
    targets: [
        .executableTarget(
            name: "AIUsageBar",
            path: "Sources/AIUsageBar",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        )
    ]
)
