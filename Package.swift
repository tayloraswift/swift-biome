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
        
    //    .package(url: "https://github.com/apple/swift-argument-parser",         from: "1.0.2"),
        .package(url: "https://github.com/apple/swift-syntax.git",              revision: "swift-5.6-DEVELOPMENT-SNAPSHOT-2022-01-09-a"),
    ],
    targets: 
    [
        .target(name: "Entrapta", 
            dependencies: 
            [
                .product(name: "JSON",                  package: "swift-json"),
                .product(name: "StructuredDocument",    package: "swift-structured-document"),
                // .product(name: "ArgumentParser",        package: "swift-argument-parser"),
                .product(name: "SwiftSyntax",           package: "swift-syntax"),
            ], 
            path: "sources/entrapta"),
    ]
)
