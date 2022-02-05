// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "entrapta",
    products: 
    [
        .executable(name: "entrapta", targets: ["Entrapta"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/kelvin13/swift-json",         branch: "master"),
        
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-syntax.git",      revision: "swift-5.6-DEVELOPMENT-SNAPSHOT-2022-01-09-a"),
    ],
    targets: 
    [
        .executableTarget(name: "Entrapta", 
            dependencies: 
            [
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
                .product(name: "SwiftSyntax",       package: "swift-syntax"),
            ], 
            path: "sources/entrapta"),
    ]
)
