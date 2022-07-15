// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "swift-biome",
    products: 
    [
        .library(name: "Biome", targets: ["Biome"]),
        .library(name: "PackageCatalog", targets: ["PackageCatalog"]),
        
        .executable(name: "preview", targets: ["Preview"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/kelvin13/swift-json",                 branch: "master"),
        .package(url: "https://github.com/kelvin13/swift-highlight",            exact: "0.1.4"),
        .package(url: "https://github.com/kelvin13/swift-resource",             exact: "0.3.0"),
        .package(url: "https://github.com/kelvin13/swift-dom",                  exact: "0.4.0"),
        
        .package(url: "https://github.com/apple/swift-markdown.git",            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-07-06-a"),
        .package(url: "https://github.com/apple/swift-syntax.git",              revision: "swift-DEVELOPMENT-SNAPSHOT-2022-07-06-a"),
        
        // only used by the PackageCatalog target
        .package(url: "https://github.com/apple/swift-system.git",              exact: "1.2.1"),
        // only used by the previewer target
        .package(url: "https://github.com/apple/swift-nio.git",                 exact: "2.40.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git",     exact: "1.1.3"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git",    exact: "1.3.2"),
    ],
    targets: 
    [
        .target(name: "Biome", 
            dependencies: 
            [
                .product(name: "DOM",               package: "swift-dom"),
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "Resources",         package: "swift-resource"),
                .product(name: "Notebook",          package: "swift-highlight"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax",       package: "swift-syntax"),
                .product(name: "Markdown",          package: "swift-markdown"),
            ]),
        
        .target(name: "PackageCatalog", 
            dependencies: 
            [
                .target(name: "Biome"),
                
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "SystemExtras",      package: "swift-resource"),
            ]),
        
        .executableTarget(name: "Preview", 
            dependencies: 
            [
                .target(name: "Biome"),
                .target(name: "PackageCatalog"),
                
                .product(name: "NIO",               package: "swift-nio"),
                .product(name: "NIOHTTP1",          package: "swift-nio"),
                .product(name: "Backtrace",         package: "swift-backtrace"),
                .product(name: "SystemPackage",     package: "swift-system"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
            ]),
    ]
)
