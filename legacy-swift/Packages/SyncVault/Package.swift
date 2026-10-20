// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SyncVault",
    platforms: [.iOS("26.0"), .macOS("15.0")],
    products: [.library(name: "SyncVault", targets: ["SyncVault"])],
    dependencies: [.package(path: "../CoreModels")],
    targets: [
        .target(
            name: "SyncVault",
            dependencies: ["CoreModels"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(name: "SyncVaultTests", dependencies: ["SyncVault"])
    ]
)
