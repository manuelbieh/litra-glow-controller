// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LitraMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "LitraMenuBar",
            path: "Sources/LitraMenuBar"
        )
    ]
)
