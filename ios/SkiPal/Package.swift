// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SkiPal",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "SkiPal",
            targets: ["SkiPal"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SkiPal",
            dependencies: [],
            path: "SkiPal",
            resources: [
                .process("Assets.xcassets"),
                .process("Base.lproj"),
                .process("Resources")
            ],
            swiftSettings: [
                .define("IOS_BUILD")
            ]
        ),
        .testTarget(
            name: "SkiPalTests",
            dependencies: ["SkiPal"],
            path: "SkiPalTests"
        ),
    ]
)
