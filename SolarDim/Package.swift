// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SolarDim",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "SolarDim", targets: ["SolarDim"]),
        .library(name: "SolarDimCore", targets: ["SolarDimCore"])
    ],
    targets: [
        .target(name: "SolarDimCore"),
        .executableTarget(
            name: "SolarDim",
            dependencies: ["SolarDimCore"],
            linkerSettings: [
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(name: "SolarDimCoreTests", dependencies: ["SolarDimCore"])
    ]
)
