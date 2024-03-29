// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "swift-biome",
    products: 
    [
        .library(name: "Versions",              targets: ["Versions"]),
        .library(name: "SymbolGraphs",          targets: ["SymbolGraphs"]),
        .library(name: "Biome",                 targets: ["Biome"]),
        .library(name: "PackageResolution",     targets: ["PackageResolution"]),
        .library(name: "PackageCatalogs",       targets: ["PackageCatalogs"]),
        .library(name: "PackageLoader",         targets: ["PackageLoader"]),
        
        .executable(name: "preview",            targets: ["Preview"]),
        .executable(name: "swift-symbolgraphc", targets: ["SymbolGraphConvert"]),
    ],
    dependencies: 
    [
        // .package(name: "swift-balanced-trees", path: "./swift-balanced-trees"),

        .package(url: "https://github.com/kelvin13/swift-json", branch: "master"),
        .package(url: "https://github.com/kelvin13/swift-grammar", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/kelvin13/swift-highlight", .upToNextMinor(from: "0.1.4")),
        .package(url: "https://github.com/kelvin13/swift-resource", .upToNextMinor(from: "0.3.2")),
        .package(url: "https://github.com/kelvin13/swift-dom", .upToNextMinor(from: "0.5.2")),
        
        .package(url: "https://github.com/apple/swift-markdown.git",    revision: "swift-DEVELOPMENT-SNAPSHOT-2022-08-24-a"),
        .package(url: "https://github.com/apple/swift-syntax.git",      revision: "swift-DEVELOPMENT-SNAPSHOT-2022-08-24-a"),
        
        // only used by the PackageLoader target
        .package(url: "https://github.com/kelvin13/swift-system-extras.git", .upToNextMinor(from: "0.2.0")),
        // only used by the Preview target
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMinor(from: "2.41.1")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.1.3")),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", .upToNextMinor(from: "1.3.2")),
    ],
    targets: 
    [
        .target(name: "Forest", path: "swift-balanced-trees/Sources/Forest"),

        .target(name: "PieCharts", 
            dependencies: 
            [
                .product(name: "SVG",               package: "swift-dom"),
            ]),
        
        .target(name: "URI", 
            dependencies: 
            [
                .product(name: "Grammar",           package: "swift-grammar"),
            ]),
        
        .target(name: "Versions", 
            dependencies: 
            [
                .product(name: "Grammar",           package: "swift-grammar"),
            ]),
        
        .target(name: "SymbolGraphs", 
            dependencies: 
            [
                .target(name: "Versions"),

                .product(name: "JSON",              package: "swift-json"),
                .product(name: "Notebook",          package: "swift-highlight"),
            ]),
        
        .target(name: "Biome", 
            dependencies: 
            [
                .target(name: "PieCharts"),
                .target(name: "SymbolGraphs"),
                .target(name: "URI"),

                .target(name: "Forest"),
                //.product(name: "Forest",            package: "swift-balanced-trees"),

                .product(name: "HTML",              package: "swift-dom"),
                .product(name: "RSS",               package: "swift-dom"),
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "Resources",         package: "swift-resource"),
                .product(name: "WebSemantics",      package: "swift-resource"),
                .product(name: "Notebook",          package: "swift-highlight"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax",       package: "swift-syntax"),
                .product(name: "Markdown",          package: "swift-markdown"),
            ], 
            swiftSettings:
            [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-move-only"]),
            ]),
        
        .target(name: "PackageResolution", 
            dependencies: 
            [
                .target(name: "SymbolGraphs"),

                .product(name: "JSON",              package: "swift-json"),
            ]),
        
        .target(name: "PackageCatalogs", 
            dependencies: 
            [
                .target(name: "SymbolGraphs"),

                .product(name: "JSON",              package: "swift-json"),
                .product(name: "SystemExtras",      package: "swift-system-extras"),
            ]),
        
        .target(name: "PackageLoader", 
            dependencies: 
            [
                .target(name: "PackageResolution"),
                .target(name: "PackageCatalogs"),
                .target(name: "Biome"),
            ]),
        
        .executableTarget(name: "SymbolGraphConvert", 
            dependencies: 
            [
                .target(name: "PackageCatalogs"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
            ]),
        
        .executableTarget(name: "Preview", 
            dependencies: 
            [
                .target(name: "PackageLoader"),
                
                .product(name: "NIO",               package: "swift-nio"),
                .product(name: "NIOHTTP1",          package: "swift-nio"),
                .product(name: "Backtrace",         package: "swift-backtrace"),
                .product(name: "SystemExtras",      package: "swift-system-extras"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
            ]),
    ]
)
