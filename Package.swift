// swift-tools-version: 6.2
import Foundation
import PackageDescription

// The code shared with the s-family: the sibling checkout when there is one,
// else the published package.
let sibling = URL(fileURLWithPath: Context.packageDirectory)
    .deletingLastPathComponent()
    .appendingPathComponent("scommon/Package.swift")
let scommon: Package.Dependency = FileManager.default.fileExists(atPath: sibling.path)
    ? .package(path: "../scommon")
    : .package(
        url: "https://github.com/uSuite/scommon.git",
        from: "0.3.0"
    )

let package = Package(
    name: "sPaste",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SPasteCore",
            targets: ["SPasteCore"]
        ),
        .executable(
            name: "sPaste",
            targets: ["sPaste"]
        ),
    ],
    dependencies: [
        scommon
    ],
    targets: [
        .target(
            name: "SPasteCore",
            dependencies: [
                .product(
                    name: "SCommon",
                    package: "scommon"
                )
            ]
        ),
        .executableTarget(
            name: "sPaste",
            dependencies: ["SPasteCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "SPasteCoreTests",
            dependencies: ["SPasteCore"]
        ),
    ]
)
