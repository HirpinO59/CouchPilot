// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CouchPilot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CouchPilot")
    ]
)
