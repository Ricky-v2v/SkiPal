// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SkiPal",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SkiPal",
            targets: ["SkiPal"]
        ),
    ],
    dependencies: [
        // 目前使用系统框架，无需外部依赖
    ],
    targets: [
        .target(
            name: "SkiPal",
            dependencies: [],
            path: "SkiPal"
        ),
    ]
)
