// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Rewind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Rewind", targets: ["Rewind"])
    ],
    targets: [
        .executableTarget(
            name: "Rewind"
        ),
        .testTarget(
            name: "RewindTests",
            dependencies: ["Rewind"]
        ),
    ]
)
