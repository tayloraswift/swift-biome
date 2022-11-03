// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "swift-biome",
    products: 
    [
        .library(name: "Multiparts",            targets: ["Multiparts"]),
        .library(name: "Sediment",              targets: ["Sediment"]),
        .library(name: "URI",                   targets: ["URI"]),
        .library(name: "Versions",              targets: ["Versions"]),

        .library(name: "SymbolAvailability",    targets: ["SymbolAvailability"]),
        .library(name: "SymbolSource",          targets: ["SymbolSource"]),
        .library(name: "SymbolGraphs",          targets: ["SymbolGraphs"]),
        .library(name: "SymbolGraphCompiler",   targets: ["SymbolGraphCompiler"]),
        .library(name: "PackageResolution",     targets: ["PackageResolution"]),

        .library(name: "MongoKittenMantle",     targets: ["MongoKittenMantle"]),

        .library(name: "BiomeDatabase",         targets: ["BiomeDatabase"]),
        .library(name: "BiomeABI",              targets: ["BiomeABI"]),
        .library(name: "Biome",                 targets: ["Biome"]),

        .plugin(name: "SymbolGraphPlugin",      targets: ["SymbolGraphPlugin"]),

        .executable(name: "swift-biome-server", targets: ["swift-biome-server"]),
        .executable(name: "swift-symbolgraphc", targets: ["swift-symbolgraphc"]),

        //.executable(name: "biome-tests",        targets: ["BiomeTests"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/kelvin13/swift-json", branch: "master"),
        .package(url: "https://github.com/kelvin13/swift-grammar", .upToNextMinor(from: "0.2.0")),
        .package(url: "https://github.com/kelvin13/swift-hash", .upToNextMinor(from: "0.2.3")),
        .package(url: "https://github.com/kelvin13/swift-highlight", .upToNextMinor(from: "0.1.4")),
        .package(url: "https://github.com/kelvin13/swift-web-semantics", .upToNextMinor(from: "0.4.0")),
        .package(url: "https://github.com/kelvin13/swift-dom", .upToNextMinor(from: "0.5.2")),
        
        // used by the _BSON module
        .package(url: "https://github.com/kelvin13/swift-package-factory.git",
            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-11-01-a"),

        .package(url: "https://github.com/apple/swift-markdown.git",
            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-11-01-a"),
        .package(url: "https://github.com/apple/swift-syntax.git",
            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-11-01-a"),
        
        // only used by the SymbolGraphCompiler target
        .package(url: "https://github.com/kelvin13/swift-system-extras.git", .upToNextMinor(from: "0.2.0")),
        // only used by the BiomeServer target
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMinor(from: "2.43.1")),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .upToNextMinor(from: "2.22.1")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.1.3")),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", .upToNextMinor(from: "1.3.2")),

        // .package(url: "https://github.com/orlandos-nl/MongoKitten", .upToNextMajor(from: "7.2.10"))
        // mongokitten’s dependencies:
        .package(url: "https://github.com/karwa/swift-url.git",     from: "0.4.1"),
        .package(url: "https://github.com/orlandos-nl/NioDNS.git",  from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git",     from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0" ..< "3.0.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
        .package(url: "https://github.com/orlandos-nl/BSON.git",    from: "8.0.0"),
    ],
    targets: 
    [
        .target(name: "Multiparts", 
            dependencies: 
            [
                .product(name: "Grammar",           package: "swift-grammar"),
            ]),
        
        .target(name: "PieCharts", 
            dependencies: 
            [
                .product(name: "SVG",               package: "swift-dom"),
            ]),
        
        .target(name: "Sediment"),
        
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
        
        .target(name: "SymbolAvailability", 
            dependencies: 
            [
                .target(name: "Versions"),
            ]),
        
        .target(name: "SymbolSource", 
            dependencies: 
            [
                .product(name: "Grammar",           package: "swift-grammar"),
                .product(name: "Notebook",          package: "swift-highlight"),
            ]),
        
        .target(name: "SymbolGraphs", 
            dependencies: 
            [
                .target(name: "SymbolSource"),
                .target(name: "SymbolAvailability"),

                .product(name: "JSON",              package: "swift-json"),
            ],
            swiftSettings:
            [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-move-only"]),
            ]),
        
        .target(name: "SymbolGraphCompiler", 
            dependencies: 
            [
                .target(name: "SymbolGraphs"),

                .product(name: "JSON",              package: "swift-json"),
                .product(name: "SystemExtras",      package: "swift-system-extras"),
            ]),
        
        .executableTarget(name: "swift-symbolgraphc", 
            dependencies: 
            [
                .target(name: "SymbolGraphCompiler"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
            ]),
        
        .plugin(name: "SymbolGraphPlugin",
            capability: .command(intent: .custom(verb: "symbolgraph", 
                description: "compile symbolgraphs and documentation")),
            dependencies: 
            [
                .target(name: "swift-symbolgraphc")
            ]),
        
        .target(name: "PackageResolution", 
            dependencies: 
            [
                .target(name: "SymbolSource"),

                .product(name: "JSON",              package: "swift-json"),
            ]),
        
        .target(name: "BiomeABI"),
        
        .target(name: "BSONTraversal"),
        .target(name: "_BSON",
            dependencies:
            [
                .target(name: "BSONTraversal")
            ],
            path: "Sources/BSON"),
        
        .target(name: "_MongoKittenCrypto"),
        .target(name: "MongoClient",
            dependencies: 
            [
                .product(name: "BSON",                  package: "BSON"),
                .product(name: "NIO",                   package: "swift-nio"),
                .product(name: "NIOSSL",                package: "swift-nio-ssl"),
                .product(name: "NIOFoundationCompat",   package: "swift-nio"),
                .product(name: "Logging",               package: "swift-log"),
                .product(name: "Metrics",               package: "swift-metrics"),
                .product(name: "Atomics",               package: "swift-atomics"),

                .product(name: "WebURL",                package: "swift-url"),

                .target(name: "_MongoKittenCrypto"),

                .product(name: "DNSClient", package: "NioDNS"),
            ],
            path: "Sources/_MongoKittenMongoClient"),
        
        .target(name: "MongoKittenMantle",
            dependencies: 
            [
                .target(name: "MongoClient"),
            ]),
        
        .target(name: "BiomeDatabase",
            dependencies: 
            [
                .target(name: "BiomeABI"),
                .target(name: "MongoKittenMantle"),
                
                .product(name: "WebSemantics",      package: "swift-web-semantics"),
            ]),
        
        .target(name: "Biome",
            dependencies: 
            [
                .target(name: "BiomeDatabase"),
                .target(name: "Multiparts"),
                .target(name: "PieCharts"),
                .target(name: "PackageResolution"),
                .target(name: "Sediment"),
                .target(name: "SymbolGraphs"),
                .target(name: "URI"),

                .product(name: "HTML",              package: "swift-dom"),
                .product(name: "RSS",               package: "swift-dom"),
                .product(name: "JSON",              package: "swift-json"),
                .product(name: "Notebook",          package: "swift-highlight"),
                .product(name: "SwiftSyntaxParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax",       package: "swift-syntax"),
                .product(name: "Markdown",          package: "swift-markdown"),
            ], 
            swiftSettings:
            [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-move-only"]),
            ]),
        
        .executableTarget(name: "swift-biome-server", 
            dependencies: 
            [
                .target(name: "Biome"),
                
                .product(name: "NIO",               package: "swift-nio"),
                .product(name: "NIOHTTP1",          package: "swift-nio"),

                .product(name: "NIOSSL",            package: "swift-nio-ssl"),

                .product(name: "Backtrace",         package: "swift-backtrace"),
                .product(name: "SystemExtras",      package: "swift-system-extras"),
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
            ], 
            swiftSettings:
            [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-move-only"]),
            ]),


        .target(name: "Testing", path: "Tests/Testing"),

        .executableTarget(name: "BSONTests",
            dependencies:
            [
                .product(name: "Base16", package: "swift-hash"),

                .target(name: "Testing"),
                .target(name: "_BSON"),
            ], 
            path: "Tests/BSONTests"),
        
        .executableTarget(name: "SedimentTests",
            dependencies:
            [
                .target(name: "Testing"),
                .target(name: "Sediment"),
            ], 
            path: "Tests/SedimentTests"),
        
        // .executableTarget(name: "BiomeTests", 
        //     dependencies: 
        //     [
        //         .target(name: "Biome"),
        //     ], 
        //     path: "Tests/BiomeTests"),
    ]
)
