// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UnitedBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "UnitedBar",
            path: "Sources/UnitedBar",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-platform_version",
                    "-Xlinker", "macos",
                    "-Xlinker", "14.0",
                    "-Xlinker", "26.0",
                ])
            ]
        )
    ]
)
