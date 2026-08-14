// swift-tools-version:5.5
//
//  Package.swift
//  StreamingTextView
//
//  Swift Package Manager 支持。
//  复用现有 CocoaPods 源码目录 StreamingTextView/Classes，无需移动文件。
//

import PackageDescription

let package = Package(
    name: "StreamingTextView",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "StreamingTextView",
            targets: ["StreamingTextView"]
        )
    ],
    targets: [
        .target(
            name: "StreamingTextView",
            path: "StreamingTextView/Classes"
        )
    ],
    swiftLanguageVersions: [.v5]
)
