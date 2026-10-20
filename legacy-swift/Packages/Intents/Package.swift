// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Intents",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "Intents", targets: ["Intents"])],
    dependencies: [.package(path: "../CoreModels"), .package(path: "../Persistence")],
    targets: [
        .target(
            name: "Intents",
            dependencies: ["CoreModels", "Persistence"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "IntentsTests", dependencies: ["Intents"])
    ]
)
