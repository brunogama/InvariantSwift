// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "CharacterizationPackage",
  platforms: [.macOS(.v14)],
  targets: [
    .testTarget(
      name: "CharacterizationPackageTests",
      path: "Tests/CharacterizationPackageTests"
    )
  ]
)
