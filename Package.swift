// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PopguideSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "PopguideSDK",
            targets: ["PopguideSDK"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "PopguideSDK",
            url: "https://github.com/populimited/popguide_sdk_sample/releases/download/1.1.0/PopguideSDK.xcframework.zip",
            checksum: "60879355b078719aed120008b3e5d076370420336f1f3812ca126677928eaa45"
        )
    ]
)
