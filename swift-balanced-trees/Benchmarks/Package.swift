// swift-tools-version:5.5
import PackageDescription

let package:Package = .init(
    name: "swift-balanced-trees-benchmarks",
    products: 
    [
        .executable(name: "forest-benchmarks", targets: ["ForestBenchmarks"]),
    ],
    dependencies: 
    [
        .package(name: "swift-balanced-trees", path: ".."),

        // .package(url: "https://github.com/kelvin13/swift-system-extras", from: "0.1.0"),
        // .package(url: "https://github.com/apple/swift-argument-parser",  from: "1.1.3"),
    ],
    targets: 
    [
        .executableTarget(name: "ForestBenchmarks",
            dependencies: 
            [
                .product(name: "Forest", package: "swift-balanced-trees"),
                // .product(name: "SystemExtras", package: "swift-system-extras"),
                // .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
    ]
)