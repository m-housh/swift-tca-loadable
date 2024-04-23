// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "swift-tca-loadable",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(name: "Loadable", targets: ["Loadable"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/pointfreeco/swift-composable-architecture.git",
      from: "1.0.0"
    ),
    .package(url: "https://github.com/pointfreeco/swift-case-paths.git", from: "1.0.0"),
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
