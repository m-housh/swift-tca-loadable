// swift-tools-version:5.7

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
    .library(name: "Loadable", targets: ["Loadable"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture.git",
      from: "0.52.0"
    ),
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "0.14.0"),
    .package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "Loadable",
      dependencies: [
        .product(name: "CasePaths", package: "swift-case-paths"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "LoadableTests",
      dependencies: [
        "Loadable"
      ]
    ),
  ]
)
