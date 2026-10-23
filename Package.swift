// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kraft",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "Kraft", targets: ["Kraft"]),
        .library(name: "KraftCore", targets: ["KraftCore"]),
    ],
    targets: [
        .target(name: "KraftCore"),
        .executableTarget(name: "Kraft", dependencies: ["KraftCore"]),
        .testTarget(name: "KraftCoreTests", dependencies: ["KraftCore"]),
    ]
)
