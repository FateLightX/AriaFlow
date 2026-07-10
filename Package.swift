// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AriaFlow",
    platforms: [
        .macOS(.v26)
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
        )
    ]
)
