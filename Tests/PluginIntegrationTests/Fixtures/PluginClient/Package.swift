// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "PluginClient",
  platforms: [.macOS(.v14)],
  dependencies: [
    .package(name: "InvariantSwift", path: "__INVARIANT_PACKAGE_PATH__")
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
