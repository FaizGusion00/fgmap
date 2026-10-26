// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fgmap_valhalla",
    // valhalla-mobile 0.6.4 menetapkan iOS 16.4 sebagai minimum.
    platforms: [
        .iOS("16.4")
    ],
    products: [
        .library(name: "fgmap-valhalla", targets: ["fgmap_valhalla"])
    ],
    dependencies: [
        // Versi dikunci tepat: ia membenamkan Valhalla 3.9.1 dan pek tile dibina dengan versi yang sama
        // (lihat tools/tiles/VERSIONS). Naikkan kedua-duanya bersama.
        .package(url: "https://github.com/Rallista/valhalla-mobile.git", exact: "0.6.4")
    ],
    targets: [
        .target(
            name: "fgmap_valhalla",
            dependencies: [
                .product(name: "Valhalla", package: "valhalla-mobile")
            ]
        )
    ]
)
