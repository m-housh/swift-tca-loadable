// swift-tools-version:5.1

import PackageDescription

let package = Package(
  name: "swift-tca-loadable",
  platforms: [
    .iOS(.v13),
    .macOS(.v10_15),
    .tvOS(.v13),
    .watchOS(.v6),
  ],
  products: [
    .library(name: "EditMode", targets: ["EditModeModifier"]),
    .library(name: "EditModeShim", targets: ["EditModeShim"]),
    .library(name: "LoadableList", targets: ["LoadableList"]),
    .library(name: "LoadablePicker", targets: ["LoadablePicker"]),
    .library(name: "LoadableView", targets: ["LoadableView"]),
    .library(name: "PreviewSupport", targets: ["PreviewSupport"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", from: "0.8.0"),
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.8.2")
  ],
  targets: [
    .target(
      name: "EditModeModifier",
      dependencies: [
        "EditModeShim",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "EditModeShim",
      dependencies: []
    ),
    .target(
      name: "LoadableList",
      dependencies: [
        "LoadableView",
        "EditModeModifier",
        "PreviewSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "LoadablePicker",
      dependencies: [
        "LoadableList",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "LoadableView",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .target(
      name: "PreviewSupport",
      dependencies: []
    ),
    .testTarget(
      name: "TCALoadableTests",
      dependencies: [
        "LoadableView",
        "SnapshotTesting"
      ]
    ),
  ]
)
