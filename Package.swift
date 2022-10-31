// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Localization",
    products: [
        .plugin(name: "LocalizationPlugin", targets: ["LocalizationPlugin"]),
        .plugin(name: "LocalizationBuildPlugin", targets: ["LocalizationBuildPlugin"])
    ],
    targets: [
        .plugin(
            name: "LocalizationPlugin",
            capability: .command(
                intent: .custom(verb: "localization", description: "Keeps your localization files clean"),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "This command sorts and groups the keys in your localization files"
                    )
                ]
            ),
            dependencies: ["Localization"]
        ),
        .plugin(
            name: "LocalizationBuildPlugin",
            capability: .buildTool(),
            dependencies: ["Localization"]
        ),
        .executableTarget(name: "localization", path: "Sources/Localization"),
        .binaryTarget(name: "Localization", path: "Binaries/Localization.artifactbundle")
    ]
)
