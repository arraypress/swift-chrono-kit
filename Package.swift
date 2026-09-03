// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-chrono-kit",
    platforms: [
        .macOS(.v14), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1),
    ],
    products: [
        .library(name: "ChronoKit", targets: ["ChronoKit"]),
    ],
    targets: [
        .target(name: "ChronoKit"),
        .testTarget(name: "ChronoKitTests", dependencies: ["ChronoKit"]),
    ]
)
