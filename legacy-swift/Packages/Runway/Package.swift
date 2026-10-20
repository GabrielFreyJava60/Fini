// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Runway",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "Runway", targets: ["Runway"])],
    dependencies: [.package(path: "../CoreModels")],
    targets: [
        .target(
            name: "Runway",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "RunwayTests", dependencies: ["Runway"])
    ]
)
