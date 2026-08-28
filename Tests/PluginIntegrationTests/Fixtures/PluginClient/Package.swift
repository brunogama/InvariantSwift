// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PluginClient",
  dependencies: [
    .package(path: "__INVARIANT_PACKAGE_PATH__")
  ],
  targets: [
    .executableTarget(
      name: "PluginClient",
      dependencies: [
        .product(name: "InvariantSwiftCore", package: "InvariantSwift")
      ]
    )
  ]
)
