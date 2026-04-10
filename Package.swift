// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenMeter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TokenMeter",
            path: "Sources",
            resources: [
                .copy("../Resources/Info.plist")
            ]
        )
    ]
)
