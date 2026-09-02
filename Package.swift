// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VerbatimMac",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "VerbatimMac", targets: ["VerbatimMac"])
    ],
    targets: [
        .executableTarget(
            name: "VerbatimMac",
            path: "Sources/VerbatimMac"
        )
    ]
)
