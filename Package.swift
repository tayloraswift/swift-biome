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

        .library(name: "MongoDB",               targets: ["MongoDB"]),

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
        //.package(url: "https://github.com/kelvin13/swift-hash", .upToNextMinor(from: "0.3.0")),
        .package(url: "https://github.com/kelvin13/swift-hash", branch: "fix-do-catch-scope"),
        .package(url: "https://github.com/kelvin13/swift-highlight", .upToNextMinor(from: "0.1.4")),
        .package(url: "https://github.com/kelvin13/swift-web-semantics", .upToNextMinor(from: "0.4.0")),
        .package(url: "https://github.com/kelvin13/swift-dom", .upToNextMinor(from: "0.5.2")),
        
        // used by the _BSON module
        .package(url: "https://github.com/kelvin13/swift-package-factory.git",
            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-11-11-a"),

        .package(url: "https://github.com/apple/swift-markdown.git",
            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-11-11-a"),
        .package(url: "https://github.com/apple/swift-syntax.git",
            revision: "swift-DEVELOPMENT-SNAPSHOT-2022-11-11-a"),
        
        // only used by the SymbolGraphCompiler target
        .package(url: "https://github.com/kelvin13/swift-system-extras.git", .upToNextMinor(from: "0.2.0")),
        // only used by the BiomeServer target
        .package(url: "https://github.com/apple/swift-nio.git", .upToNextMinor(from: "2.43.1")),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .upToNextMinor(from: "2.22.1")),
        .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.1.3")),
        .package(url: "https://github.com/swift-server/swift-backtrace.git", .upToNextMinor(from: "1.3.2")),

        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.0.0"),
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
        
        .target(name: "TraceableErrors"),

        .target(name: "UUID",
            dependencies:
            [
                .product(name: "Base16", package: "swift-hash"),
            ]),

        .target(name: "BSONTraversal"),
        .target(name: "BSON",
            dependencies:
            [
                .target(name: "BSONTraversal"),
            ]),
        .target(name: "BSONPrimitives",
            dependencies:
            [
                .target(name: "BSON"),
            ]),
        .target(name: "BSONDecoding",
            dependencies:
            [
                .target(name: "BSONPrimitives"),
                .target(name: "TraceableErrors"),
            ]),
        .target(name: "BSONEncoding",
            dependencies:
            [
                .target(name: "BSONPrimitives"),
            ]),
        .target(name: "BSONSchema",
            dependencies:
            [
                .target(name: "BSONDecoding"),
                .target(name: "BSONEncoding"),
            ]),
        
        .target(name: "SCRAM",
            dependencies: 
            [
                .product(name: "Base64",                package: "swift-hash"),
                .product(name: "MessageAuthentication", package: "swift-hash"),
            ]),

        // the mongo wire protocol. has no awareness of networking or
        // driver-level concepts.
        .target(name: "MongoWire",
            dependencies: 
            [
                .target(name: "BSON"),
                .product(name: "CRC", package: "swift-hash"),
            ]),
        
        // basic type definitions and conformances. driver peripherals can
        // import this instead of ``/MongoDriver`` to avoid depending on `swift-nio`.
        .target(name: "Mongo",
            dependencies: 
            [
                // this dependency emerged because we need several of the
                // enumeration types to be ``BSONDecodable`` and ``BSONEncodable``,
                // and we do not want a downstream module to have to declare
                // retroactive conformances.
                .target(name: "BSONSchema"),
            ]),

        // connection uri strings.
        .target(name: "MongoURI",
            dependencies: 
            [
                .target(name: "Mongo"),
            ]),
        
        
        .target(name: "MongoSchema",
            dependencies: 
            [
                .target(name: "BSONSchema"),
            ]),

        .target(name: "MongoDriver",
            dependencies: 
            [
                .target(name: "Mongo"),
                .target(name: "MongoSchema"),
                .target(name: "MongoWire"),
                .target(name: "SCRAM"),
                .target(name: "TraceableErrors"),
                .target(name: "UUID"),

                .product(name: "Base64",                package: "swift-hash"),
                .product(name: "MessageAuthentication", package: "swift-hash"),
                .product(name: "SHA2",                  package: "swift-hash"),
                .product(name: "NIOCore",               package: "swift-nio"),
                .product(name: "NIOPosix",              package: "swift-nio"),
                .product(name: "NIOSSL",                package: "swift-nio-ssl"),
                .product(name: "Atomics",               package: "swift-atomics"),
            ]),
        
        .target(name: "MongoDB",
            dependencies: 
            [
                .target(name: "MongoDriver"),
            ]),
        
        .target(name: "BiomeDatabase",
            dependencies: 
            [
                .target(name: "BiomeABI"),
                .target(name: "MongoDB"),
                
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
                //.product(name: "IDEUtils",          package: "swift-syntax"),
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
                
                .product(name: "NIOCore",           package: "swift-nio"),
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


        .executableTarget(name: "BSONTests",
            dependencies:
            [
                .target(name: "BSON"),
                .product(name: "Base16", package: "swift-hash"),
                .product(name: "Testing", package: "swift-hash"),
            ], 
            path: "Tests/BSON"),
        
        .executableTarget(name: "BSONDecodingTests",
            dependencies:
            [
                .target(name: "BSONDecoding"),
                .product(name: "Testing", package: "swift-hash"),
            ], 
            path: "Tests/BSONDecoding"),
        
        .executableTarget(name: "BSONEncodingTests",
            dependencies:
            [
                .target(name: "BSONEncoding"),
                .product(name: "Testing", package: "swift-hash"),
            ], 
            path: "Tests/BSONEncoding"),
        
        .executableTarget(name: "MongoDBTests",
            dependencies:
            [
                .target(name: "MongoDB"),
                // already included by `MongoDriver`’s transitive `NIOSSL` dependency,
                // but restated here for clarity.
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Testing", package: "swift-hash"),
            ], 
            path: "Tests/MongoDB"),
        
        .executableTarget(name: "MongoDriverTests",
            dependencies:
            [
                .target(name: "MongoDriver"),
                // already included by `MongoDriver`’s transitive `NIOSSL` dependency,
                // but restated here for clarity.
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Testing", package: "swift-hash"),
            ], 
            path: "Tests/MongoDriver"),
        
        .executableTarget(name: "SedimentTests",
            dependencies:
            [
                .target(name: "Sediment"),
                .product(name: "Testing", package: "swift-hash"),
            ], 
            path: "Tests/Sediment"),
        
        // .executableTarget(name: "BiomeTests", 
        //     dependencies: 
        //     [
        //         .target(name: "Biome"),
        //     ], 
        //     path: "Tests/BiomeTests"),
    ]
)
