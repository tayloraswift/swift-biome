// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Entrapta",
    products: 
    [
        .executable(name: "entrapta", targets: ["Entrapta"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
    ],
    targets: 
    [
        .target(name: "Entrapta", 
            dependencies: 
            [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ], 
            path: "sources/"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
