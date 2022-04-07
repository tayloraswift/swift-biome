// swift-tools-version:5.6
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
        .package(url: "https://github.com/kelvin13/swift-highlight",            from:   "0.1.0"),
        .package(url: "https://github.com/kelvin13/swift-resource",             branch: "master"),
        .package(url: "https://github.com/kelvin13/swift-structured-document",  branch: "master"),
        
        .package(url: "https://github.com/apple/swift-markdown.git",            branch: "main"),
        .package(url: "https://github.com/apple/swift-syntax.git",              revision: "swift-DEVELOPMENT-SNAPSHOT-2022-04-04-a"),
        
        // only used by the index target
        .package(url: "https://github.com/apple/swift-system.git",              branch: "main"),
        // only used by the previewer target
        .package(url: "https://github.com/apple/swift-nio.git",                 from: "2.39.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git",     from: "1.1.1"),
        .package(url: "https://github.com/swift-server/swift-backtrace.git",    from: "1.3.1"),
    ],
    targets: 
    [
        .target(name: "Biome", 
            dependencies: 
            [
                .product(name: "JSON",                  package: "swift-json"),
                .product(name: "Highlight",             package: "swift-highlight"),
                .product(name: "StructuredDocument",    package: "swift-structured-document"),
                .product(name: "SwiftSyntaxParser",     package: "swift-syntax"),
                .product(name: "SwiftSyntax",           package: "swift-syntax"),
                .product(name: "Markdown",              package: "swift-markdown"),
            ], 
            path: "sources/biome"),
        
        .target(name: "BiomeIndex", 
            dependencies: 
            [
                .target(name: "Biome"),
                .product(name: "JSON",                  package: "swift-json"),
                .product(name: "Bureaucrat",            package: "swift-resource"),
                .product(name: "SystemPackage",         package: "swift-system"),
            ], 
            path: "sources/index"),
        
        .target(name: "BiomeTemplates", 
            dependencies: 
            [
                .target(name: "Biome"),
                .product(name: "StructuredDocument",    package: "swift-structured-document"),
            ], 
            path: "sources/templates"),
        
        .executableTarget(name: "Preview", 
            dependencies: 
            [
                .target(name: "Biome"),
                .target(name: "BiomeIndex"),
                .target(name: "BiomeTemplates"),
                
                .product(name: "NIO",                   package: "swift-nio"),
                .product(name: "NIOHTTP1",              package: "swift-nio"),
                .product(name: "Backtrace",             package: "swift-backtrace"),
                .product(name: "SystemPackage",         package: "swift-system"),
                .product(name: "ArgumentParser",        package: "swift-argument-parser"),
            ], 
            path: "sources/preview"),
    ]
)
