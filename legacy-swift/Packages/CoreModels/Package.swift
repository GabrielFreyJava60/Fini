// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoreModels",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "CoreModels", targets: ["CoreModels"])],
    targets: [
        // Pure Swift + Foundation. No Apple-only frameworks, so it builds and tests on Linux CI too.
        .target(name: "CoreModels", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "CoreModelsTests", dependencies: ["CoreModels"])
    ]
)
