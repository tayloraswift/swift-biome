// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "Entrapta",
    products: 
    [
        .executable(name: "entrapta", targets: ["Entrapta"]),
    ],
    targets: 
    [
        .target(name: "Entrapta", dependencies: [], path: "sources/"),
    ], 
    swiftLanguageVersions: [.v4_2, .v5]
)
