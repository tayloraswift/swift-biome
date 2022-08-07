// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "swift-balanced-trees",
    products: 
    [
        .library(name: "Forest",            targets: ["Forest"]),
        .executable(name: "forest-tests",   targets: ["ForestTests"]),
    ],
    dependencies: 
    [
    ],
    targets: 
    [
        .target(name: "Forest", 
            dependencies: 
            [
            ]),
        
        .executableTarget(name: "ForestTests", 
            dependencies: 
            [
                .target(name: "Forest"),
            ], 
            path: "Tests/ForestTests"),
    ]
)
