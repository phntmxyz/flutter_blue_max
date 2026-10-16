// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_blue_max_darwin",
    platforms: [
        .iOS("12.0"),
        .macOS("10.14"),
    ],
    products: [
        .library(name: "flutter-blue-max-darwin", targets: ["flutter_blue_max_darwin"])
    ],
    dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
    targets: [
        .target(
            name: "flutter_blue_max_darwin",
            dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")],
            cSettings: [
                .headerSearchPath("include/flutter_blue_max_darwin")
            ]
        )
    ]
)
