// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PokerAssistant",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PokerCore", targets: ["PokerCore"]),
        .library(name: "PokerUI", targets: ["PokerUI"])
    ],
    targets: [
        .target(name: "PokerCore"),
        .target(name: "PokerUI", dependencies: ["PokerCore"]),
        .testTarget(name: "PokerCoreTests", dependencies: ["PokerCore"]),
        .testTarget(name: "PokerUITests", dependencies: ["PokerUI", "PokerCore"])
    ]
)
