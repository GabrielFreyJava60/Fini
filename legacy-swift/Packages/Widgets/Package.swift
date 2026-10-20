// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Widgets",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "Widgets", targets: ["Widgets"])],
    dependencies: [.package(path: "../CoreModels"), .package(path: "../DesignSystem")],
    targets: [
        .target(
            name: "Widgets",
            dependencies: ["CoreModels", "DesignSystem"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "WidgetsTests", dependencies: ["Widgets"])
    ]
)
