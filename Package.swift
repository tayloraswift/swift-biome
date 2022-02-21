// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "swift-biome",
    products: 
    [
        .library(name: "Biome", targets: ["Biome"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/kelvin13/swift-json",                 from: "0.1.4"),
        .package(url: "https://github.com/kelvin13/swift-structured-document",  branch: "master"),
        
        .package(url: "https://github.com/apple/swift-markdown.git",            branch: "main"),
        .package(url: "https://github.com/kelvin13/swift-syntax.git",           branch: "kelvin13-omit-unsafe-flags"),
    ],
    targets: 
    [
        .target(name: "Biome", 
            dependencies: 
            [
                .product(name: "JSON",                  package: "swift-json"),
                .product(name: "StructuredDocument",    package: "swift-structured-document"),
                .product(name: "SwiftSyntaxParser",     package: "swift-syntax"),
                .product(name: "SwiftSyntax",           package: "swift-syntax"),
                .product(name: "Markdown",              package: "swift-markdown"),
            ], 
            path: "sources/biome"),
    ]
)
