// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexResetCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "CodexResetCore", targets: ["CodexResetCore"])],
    targets: [
        .target(name: "CodexResetCore", path: "Shared"),
        .testTarget(name: "CodexResetCoreTests", dependencies: ["CodexResetCore"], path: "Tests")
    ]
)
