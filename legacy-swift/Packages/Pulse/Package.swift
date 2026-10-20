// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "Pulse", targets: ["Pulse"])],
    dependencies: [.package(path: "../CoreModels")],
    targets: [
        .target(
            name: "Pulse",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "PulseTests", dependencies: ["Pulse"])
    ]
)
