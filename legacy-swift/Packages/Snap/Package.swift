// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Snap",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "Snap", targets: ["Snap"])],
    dependencies: [.package(path: "../CoreModels")],
    targets: [
        .target(
            name: "Snap",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "SnapTests", dependencies: ["Snap"])
    ]
)
