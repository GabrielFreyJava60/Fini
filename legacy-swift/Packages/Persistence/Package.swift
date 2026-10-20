// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Persistence",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "Persistence", targets: ["Persistence"])],
    dependencies: [.package(path: "../CoreModels")],
    targets: [
        .target(
            name: "Persistence",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"])
    ]
)
