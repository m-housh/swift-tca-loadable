// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "TCALoadable",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(name: "LoadableList", targets: ["LoadableList"]),
    .library(name: "TCALoadable", targets: ["TCALoadable"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.8.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.8.2")
  ],
  targets: [
    .target(
      name: "LoadableList",
      dependencies: [
        "TCALoadable",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "TCALoadable",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "TCALoadableTests",
      dependencies: [
        "TCALoadable",
        "SnapshotTesting"
      ]
    ),
  ]
)
