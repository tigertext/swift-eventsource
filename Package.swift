// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "LDSwiftEventSourceCustomized",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
        .watchOS(.v4),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "LDSwiftEventSourceCustomized", targets: ["LDSwiftEventSourceCustomized"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LDSwiftEventSourceCustomized",
            path: "Source"),
        .testTarget(
            name: "LDSwiftEventSourceTests",
            dependencies: ["LDSwiftEventSource"],
            path: "Tests"),
    ],
    swiftLanguageVersions: [.v5])
