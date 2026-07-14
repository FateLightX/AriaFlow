// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AriaFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AriaFlow", targets: ["AriaFlow"])
    ],
    targets: [
        .executableTarget(
            name: "AriaFlow",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "AriaFlowTests",
            dependencies: ["AriaFlow"]
        )
    ]
)
