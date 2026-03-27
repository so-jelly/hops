// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hops",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0"),
    ],
    targets: [
        .target(
            name: "HopsCore",
            dependencies: ["TOMLKit"],
            path: "Sources/HopsCore"
        ),
        .executableTarget(
            name: "hops",
            dependencies: ["HopsCore"],
            path: "Sources/hops"
        ),
        .testTarget(
            name: "HopsTests",
            dependencies: ["HopsCore"],
            path: "Tests"
        ),
    ]
)
