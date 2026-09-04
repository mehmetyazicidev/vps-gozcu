// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VPSGozcu",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VPSGozcu", targets: ["VPSGozcu"])
    ],
    targets: [
        .executableTarget(name: "VPSGozcu"),
        .testTarget(name: "VPSGozcuTests", dependencies: ["VPSGozcu"])
    ]
)
