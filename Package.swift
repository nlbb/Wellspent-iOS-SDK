// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "WellspentSDK",
    platforms: [
        .iOS(.v14),
    ],
    products: [
        .library(
            name: "WellspentSDK",
            targets: ["WellspentSDK"]
        ),
    ],
    targets: [
        .target(
            name: "RuntimeLog"
        ),
        .target(
            name: "WellspentSDK",
            dependencies: [
                "RuntimeLog"
            ],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "WellspentSDKTests",
            dependencies: ["WellspentSDK"]
        ),
    ]
)
