// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "entrapta",
    products: 
    [
        .library(name: "Entrapta", targets: ["Entrapta"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/kelvin13/swift-json",                 from: "0.1.4"),
        .package(url: "https://github.com/kelvin13/swift-structured-document",  branch: "master"),
        
        .package(url: "https://github.com/apple/swift-markdown.git",            branch: "main"),
        .package(url: "https://github.com/apple/swift-syntax.git",              revision: "swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a"),
    ],
    targets: 
    [
        .target(name: "Entrapta", 
            dependencies: 
            [
                .product(name: "JSON",                  package: "swift-json"),
                .product(name: "StructuredDocument",    package: "swift-structured-document"),
                .product(name: "SwiftSyntax",           package: "swift-syntax"),
                .product(name: "Markdown",              package: "swift-markdown"),
            ], 
            path: "sources/entrapta"),
    ]
)
