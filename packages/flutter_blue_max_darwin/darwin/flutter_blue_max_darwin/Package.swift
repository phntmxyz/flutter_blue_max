// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Flutter 3.41 and newer vend the engine as the FlutterFramework package next to the plugin packages and expect
// plugins to depend on it. Older versions put the engine on the framework search path and have no such package,
// so depending on it there would fail the package resolution.
let flutterFramework = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("FlutterFramework")
let hasFlutterFramework = FileManager.default.fileExists(
    atPath: flutterFramework.appendingPathComponent("Package.swift").path
)

let package = Package(
    name: "flutter_blue_max_darwin",
    platforms: [
        .iOS("12.0"),
        .macOS("10.14"),
    ],
    products: [
        .library(name: "flutter-blue-max-darwin", targets: ["flutter_blue_max_darwin"])
    ],
    dependencies: hasFlutterFramework ? [.package(name: "FlutterFramework", path: "../FlutterFramework")] : [],
    targets: [
        .target(
            name: "flutter_blue_max_darwin",
            dependencies: hasFlutterFramework ? [.product(name: "FlutterFramework", package: "FlutterFramework")] : [],
            cSettings: [
                .headerSearchPath("include/flutter_blue_max_darwin")
            ],
            linkerSettings: [
                .linkedFramework("IOBluetooth", .when(platforms: [.macOS]))
            ]
        )
    ]
)
