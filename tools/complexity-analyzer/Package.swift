// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "complexity-analyzer",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "complexity-analyzer", targets: ["ComplexityAnalyzer"]),
        .library(name: "ComplexityCore", targets: ["ComplexityCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "603.0.0"),
        .package(url: "https://github.com/apple/indexstore-db.git", branch: "release/6.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
    ],
    targets: [
        .executableTarget(
            name: "ComplexityAnalyzer",
            dependencies: [
                "ComplexityCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "ComplexityCore",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "IndexStoreDB", package: "indexstore-db"),
            ]
        ),
        .testTarget(
            name: "ComplexityCoreTests",
            dependencies: ["ComplexityCore"]
        ),
    ]
)
