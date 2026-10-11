// swift-tools-version:5.9
import PackageDescription

// TourCore is deliberately free of UIKit/ARKit/RealityKit/GoogleMaps so it can be
// built and unit-tested on any platform with a Swift toolchain (including Linux CI).
let package = Package(
    name: "TourCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "TourCore", targets: ["TourCore"])
    ],
    targets: [
        .target(
            name: "TourCore",
            path: "Sources/TourCore"
        ),
        .testTarget(
            name: "TourCoreTests",
            dependencies: ["TourCore"],
            path: "Tests/TourCoreTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
