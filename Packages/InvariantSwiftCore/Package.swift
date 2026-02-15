// swift-tools-version: 6.0

import PackageDescription

let commonSwiftSettings: [SwiftSetting] = [
  .unsafeFlags([
    "-Xfrontend", "-strict-concurrency=complete",
    "-Xfrontend", "-warn-concurrency",
  ]),
  .enableUpcomingFeature("StrictConcurrency"),
]

let packagePlatforms: [SupportedPlatform] = [
  .iOS(.v17),
  .macOS(.v14),
  .tvOS(.v17),
  .watchOS(.v10),
  .macCatalyst(.v17),
]

let package = Package(
  name: "InvariantSwiftCore",
  platforms: packagePlatforms,
  products: [
    // Layer 0: Foundation
    .library(name: "InvariantSwiftCore", targets: ["InvariantSwiftCore"]),
    // Layer 1: Building Blocks
    .library(name: "InvariantSwiftGenerators", targets: ["InvariantSwiftGenerators"]),
    .library(name: "InvariantSwiftExecution", targets: ["InvariantSwiftExecution"]),
    // Layer 2: Main Library
    .library(name: "InvariantSwift", targets: ["InvariantSwift"]),
    // Layer 3: Extensions
    .library(name: "InvariantSwiftAdvanced", targets: ["InvariantSwiftAdvanced"]),
    // Domain Generators
    .library(name: "InvariantSwiftDomainGenerators", targets: ["InvariantSwiftDomainGenerators"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3")
  ],
  targets: [
    // MARK: - Layer 0: Foundation (zero dependencies)
    .target(
      name: "InvariantSwiftCore",
      dependencies: [],
      path: "Sources/InvariantSwiftCore",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 1: Building Blocks (depend only on Core)
    .target(
      name: "InvariantSwiftGenerators",
      dependencies: ["InvariantSwiftCore"],
      path: "Sources/InvariantSwiftGenerators",
      swiftSettings: commonSwiftSettings
    ),
    .target(
      name: "InvariantSwiftExecution",
      dependencies: ["InvariantSwiftCore"],
      path: "Sources/InvariantSwiftExecution",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 2: Main Library (combines internal modules)
    .target(
      name: "InvariantSwift",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwiftGenerators",
        "InvariantSwiftExecution",
      ],
      path: "Sources/InvariantSwift",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 3: Extensions (depend on main library)
    .target(
      name: "InvariantSwiftAdvanced",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
      ],
      path: "Sources/InvariantSwiftAdvanced",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Domain Generators
    .target(
      name: "InvariantSwiftDomainGenerators",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
      ],
      path: "Sources/InvariantSwiftDomainGenerators",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Tests
    .testTarget(
      name: "InvariantSwiftCoreTests",
      dependencies: ["InvariantSwiftCore"],
      path: "Tests/InvariantSwiftCoreTests",
      swiftSettings: commonSwiftSettings
    ),
    .testTarget(
      name: "InvariantSwiftTests",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwift",
        "InvariantSwiftAdvanced",
      ],
      path: "Tests/InvariantSwiftTests",
      swiftSettings: commonSwiftSettings
    ),
    .testTarget(
      name: "InvariantSwiftDomainGeneratorsTests",
      dependencies: [
        "InvariantSwiftDomainGenerators",
        "InvariantSwift",
      ],
      path: "Tests/InvariantSwiftDomainGeneratorsTests",
      swiftSettings: commonSwiftSettings
    ),
    .testTarget(
      name: "PerformanceTests",
      dependencies: [
        "InvariantSwift",
        "InvariantSwiftAdvanced",
      ],
      path: "Tests/PerformanceTests",
      swiftSettings: commonSwiftSettings
    ),
  ]
)
