// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LiteLLMUsageBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "LiteLLMUsageBarCore", targets: ["LiteLLMUsageBarCore"]),
        .executable(name: "LiteLLMUsageBar", targets: ["LiteLLMUsageBar"])
    ],
    targets: [
        .target(
            name: "LiteLLMUsageBarCore",
            dependencies: []
        ),
        .executableTarget(
            name: "LiteLLMUsageBar",
            dependencies: ["LiteLLMUsageBarCore"]
        ),
        .testTarget(
            name: "LiteLLMUsageBarCoreTests",
            dependencies: ["LiteLLMUsageBarCore"]
        )
    ]
)
