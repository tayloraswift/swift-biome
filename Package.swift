// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "swift-biome",
    products: 
    [
        .library(name: "Biome", targets: ["Biome"]),
        .library(name: "BiomeIndex", targets: ["BiomeIndex"]),
        .library(name: "BiomeTemplates", targets: ["BiomeTemplates"]),
        .executable(name: "preview", targets: ["Preview"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/kelvin13/swift-json",                 branch: "master"),
        .package(url: "https://github.com/kelvin13/swift-highlight",            exact: "0.1.3"),
        .package(url: "https://github.com/kelvin13/swift-resource",             exact: "0.2.2"),
        .package(url: "https://github.com/kelvin13/swift-dom",                  exact: "0.3.7"),
        
        .package(url: "https://github.com/apple/swift-markdown.git",            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-05-31-a"),
        .package(url: "https://github.com/apple/swift-syntax.git",              revision: "swift-DEVELOPMENT-SNAPSHOT-2022-05-31-a"),
        
        // only used by the index target
        .package(url: "https://github.com/apple/swift-system.git",              exact: "1.2.1"),
        // only used by the previewer target
        .package(url: "https://github.com/apple/swift-nio.git",                 exact: "2.40.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git",     exact: "1.1.2"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git",    exact: "1.3.2"),
    ],
    targets: 
    [
        .target(name: "Biome", 
            dependencies: 
            [
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "DOM",               package: "swift-dom"),
                .product(name: "Notebook",          package: "swift-highlight"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax",       package: "swift-syntax"),
                .product(name: "Markdown",          package: "swift-markdown"),
            ], 
            path: "sources/biome"),
        
        .target(name: "BiomeIndex", 
            dependencies: 
            [
                .target(name: "Biome"),
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "VersionControl",    package: "swift-resource"),
            ], 
            path: "sources/index"),
        
        .target(name: "BiomeTemplates", 
            dependencies: 
            [
                .target(name: "Biome"),
                .product(name: "DOM",               package: "swift-dom"),
            ], 
            path: "sources/templates"),
        
        .executableTarget(name: "Preview", 
            dependencies: 
            [
                .target(name: "Biome"),
                .target(name: "BiomeIndex"),
                .target(name: "BiomeTemplates"),
                
                .product(name: "NIO",               package: "swift-nio"),
                .product(name: "NIOHTTP1",          package: "swift-nio"),
                .product(name: "Backtrace",         package: "swift-backtrace"),
                .product(name: "SystemPackage",     package: "swift-system"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
            ], 
            path: "sources/preview"),
    ]
)
