// swift-tools-version: 5.9
// Swift Package Manager (Flutter 3.24+); fg_device_music.podspec tetap ada untuk projek CocoaPods.

import PackageDescription

let package = Package(
    name: "fg_device_music",
    platforms: [
        .iOS("16.4")
    ],
    products: [
        .library(name: "fg-device-music", targets: ["fg_device_music"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "fg_device_music",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
