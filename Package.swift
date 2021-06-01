// swift-tools-version:5.5
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
        .package(url: "https://github.com/apple/swift-syntax.git", .revision("swift-DEVELOPMENT-SNAPSHOT-2021-05-18-a")),
    ],
    targets: 
    [
        .executableTarget(name: "Entrapta", 
            dependencies: 
            [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftSyntax",    package: "swift-syntax"),
            ], 
            path: "sources/"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
