// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KaraokeMaker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KaraokeMaker",
            path: "Sources/KaraokeMaker"
        )
    ]
)
