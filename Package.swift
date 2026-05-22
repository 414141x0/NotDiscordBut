// swift-tools-version: 6.3

import PackageDescription

let releaseSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
]

let releaseLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-dead_strip"], .when(configuration: .release))
]

let package = Package(
    name: "NotDiscordBut",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DiscordPrimitives", targets: ["DiscordPrimitives"]),
        .library(name: "DiscordHTTP", targets: ["DiscordHTTP"]),
        .library(name: "DiscordAuth", targets: ["DiscordAuth"]),
        .library(name: "DiscordGateway", targets: ["DiscordGateway"]),
        .library(name: "DiscordPersistence", targets: ["DiscordPersistence"]),
        .library(name: "DiscordState", targets: ["DiscordState"]),
        .library(name: "DiscordFeatures", targets: ["DiscordFeatures"]),
        .library(name: "DiscordKit", targets: ["DiscordKit"]),
        .executable(name: "NotDiscordButMac", targets: ["NotDiscordButMac"])
    ],
    targets: [
        .target(
            name: "DiscordPrimitives",
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .target(
            name: "DiscordHTTP",
            dependencies: ["DiscordPrimitives"],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .target(
            name: "DiscordGateway",
            dependencies: ["DiscordPrimitives", "DiscordHTTP"],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .target(
            name: "DiscordPersistence",
            dependencies: ["DiscordPrimitives"],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Security")
            ] + releaseLinkerSettings
        ),
        .target(
            name: "DiscordAuth",
            dependencies: ["DiscordPrimitives", "DiscordHTTP", "DiscordPersistence"],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: [
                .linkedFramework("Security")
            ] + releaseLinkerSettings
        ),
        .target(
            name: "DiscordState",
            dependencies: ["DiscordPrimitives", "DiscordPersistence"],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .target(
            name: "DiscordFeatures",
            dependencies: [
                "DiscordPrimitives",
                "DiscordHTTP",
                "DiscordGateway",
                "DiscordAuth",
                "DiscordPersistence",
                "DiscordState"
            ],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .target(
            name: "DiscordKit",
            dependencies: [
                "DiscordPrimitives",
                "DiscordHTTP",
                "DiscordGateway",
                "DiscordAuth",
                "DiscordPersistence",
                "DiscordState",
                "DiscordFeatures"
            ],
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .executableTarget(
            name: "NotDiscordButMac",
            dependencies: ["DiscordKit"],
            path: "Apps/NotDiscordButMac/Sources/NotDiscordButMac",
            swiftSettings: releaseSwiftSettings,
            linkerSettings: releaseLinkerSettings
        ),
        .testTarget(
            name: "DiscordPrimitivesTests",
            dependencies: ["DiscordPrimitives"]
        ),
        .testTarget(
            name: "DiscordHTTPTests",
            dependencies: ["DiscordHTTP"]
        ),
        .testTarget(
            name: "DiscordAuthTests",
            dependencies: ["DiscordAuth"]
        ),
        .testTarget(
            name: "DiscordGatewayTests",
            dependencies: ["DiscordGateway"]
        ),
        .testTarget(
            name: "DiscordPersistenceTests",
            dependencies: ["DiscordPersistence"]
        ),
        .testTarget(
            name: "DiscordStateTests",
            dependencies: ["DiscordState"]
        ),
        .testTarget(
            name: "DiscordFeaturesTests",
            dependencies: ["DiscordFeatures"]
        ),
        .testTarget(
            name: "DiscordKitTests",
            dependencies: ["DiscordKit", "DiscordHTTP"]
        ),
        .testTarget(
            name: "NotDiscordButMacTests",
            dependencies: ["NotDiscordButMac"]
        )
    ],
    swiftLanguageModes: [.v6]
)
