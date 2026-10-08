// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NotchMusic",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(
            name: "NotchMusic",
            path: "Sources/NotchMusic"
        )
    ]
)
