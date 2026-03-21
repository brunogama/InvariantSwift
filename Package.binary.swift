// swift-tools-version: 6.2
// Package.binary.swift -- Release manifest for binary macro distribution.
// On tagged releases, CI swaps this file to Package.swift so consumers resolve
// the pre-built InvariantSwiftMacros target without pulling swift-syntax.
import PackageDescription

// Swift 6 enables StrictConcurrency by default; no additional flags needed.
let commonSwiftSettings: [SwiftSetting] = []

let packagePlatforms: [SupportedPlatform] = [
  .iOS(.v17),
  .macOS(.v14),
  .tvOS(.v17),
  .watchOS(.v10),
  .macCatalyst(.v17),
]

let packageProducts: [Product] = [
  .library(name: "InvariantSwiftCore", targets: ["InvariantSwiftCore"]),
  .library(name: "InvariantSwiftGenerators", targets: ["InvariantSwiftGenerators"]),
  .library(name: "InvariantSwiftExecution", targets: ["InvariantSwiftExecution"]),
  .library(name: "InvariantSwift", targets: ["InvariantSwift"]),
  .library(name: "InvariantSwiftAdvanced", targets: ["InvariantSwiftAdvanced"]),
  .library(name: "InvariantSwiftDomainGenerators", targets: ["InvariantSwiftDomainGenerators"]),
  .library(name: "InvariantSwiftMacroAPI", targets: ["InvariantSwiftMacroAPI"]),
  .library(name: "InvariantSwiftTesting", targets: ["InvariantSwiftTesting"]),
  .library(name: "InvariantSwiftUmbrella", targets: ["InvariantSwiftUmbrella"]),
  .plugin(name: "InvariantSwiftPlugin", targets: ["InvariantSwiftPlugin"]),
]

// No swift-syntax, swift-benchmark, or MacroTemplateKit in the binary manifest.
let packageDependencies: [Package.Dependency] = []

// MARK: - Core Libraries

let coreTargets: [Target] = [
  .target(
    name: "InvariantSwiftCore",
    dependencies: [],
    path: "Packages/InvariantSwiftCore/Sources/InvariantSwiftCore",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantSwiftGenerators",
    dependencies: ["InvariantSwiftCore"],
    path: "Packages/InvariantSwiftCore/Sources/InvariantSwiftGenerators",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantSwiftExecution",
    dependencies: ["InvariantSwiftCore"],
    path: "Packages/InvariantSwiftCore/Sources/InvariantSwiftExecution",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantSwift",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwiftGenerators",
      "InvariantSwiftExecution",
    ],
    path: "Packages/InvariantSwiftCore/Sources/InvariantSwift",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantSwiftAdvanced",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
    ],
    path: "Packages/InvariantSwiftCore/Sources/InvariantSwiftAdvanced",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantSwiftDomainGenerators",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
    ],
    path: "Packages/InvariantSwiftCore/Sources/InvariantSwiftDomainGenerators",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Compile-Time Macro Surface

let macroTargets: [Target] = [
  .binaryTarget(
    name: "InvariantSwiftMacros",
    url:
      "https://github.com/brunogama/InvariantSwift/releases/download/__VERSION__/InvariantSwiftMacros.artifactbundle.zip",
    checksum: "__CHECKSUM__"
  ),
  .target(
    name: "InvariantSwiftMacroAPI",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
      "InvariantSwiftMacros",
    ],
    path: "Packages/InvariantSwiftMacros/Sources/InvariantSwiftMacroAPI",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Swift Testing Runtime

let testingTargets: [Target] = [
  .target(
    name: "InvariantSwiftTesting",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
    ],
    path: "Sources/InvariantSwiftTestingIntegration",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Umbrella

let umbrellaTargets: [Target] = [
  .target(
    name: "InvariantSwiftUmbrella",
    dependencies: [
      "InvariantSwiftTesting",
      "InvariantSwift",
      "InvariantSwiftCore",
      "InvariantSwiftMacroAPI",
    ],
    path: "Sources/InvariantSwiftUmbrella",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Plugins

let pluginTargets: [Target] = [
  .plugin(
    name: "InvariantSwiftPlugin",
    capability: .command(
      intent: .custom(verb: "invariant", description: "Run property-based tests"),
      permissions: [.writeToPackageDirectory(reason: "Generate test reports")]
    ),
    dependencies: [],
    path: "Plugins/InvariantSwiftPlugin"
  )
]

// MARK: - Tests

let testTargets: [Target] = [
  .testTarget(
    name: "InvariantSwiftCoreTests",
    dependencies: ["InvariantSwiftCore"],
    path: "Packages/InvariantSwiftCore/Tests/InvariantSwiftCoreTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "InvariantSwiftTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
    ],
    path: "Packages/InvariantSwiftCore/Tests/InvariantSwiftTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "InvariantSwiftDomainGeneratorsTests",
    dependencies: [
      "InvariantSwiftDomainGenerators",
      "InvariantSwift",
    ],
    path: "Packages/InvariantSwiftCore/Tests/InvariantSwiftDomainGeneratorsTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "PerformanceTests",
    dependencies: [
      "InvariantSwift",
      "InvariantSwiftAdvanced",
    ],
    path: "Packages/InvariantSwiftCore/Tests/PerformanceTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "CoverageIntegrationTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
      "InvariantSwiftTesting",
    ],
    path: "Tests/CoverageIntegrationTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "GeneratedPropertyTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
      "InvariantSwiftTesting",
      "InvariantSwiftMacroAPI",
    ],
    path: "Tests/GeneratedPropertyTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "SmokeTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
      "InvariantSwiftTesting",
      "InvariantSwiftMacroAPI",
    ],
    path: "Tests/SmokeTests",
    swiftSettings: commonSwiftSettings
  ),
]

let allTargets =
  coreTargets
  + macroTargets
  + testingTargets
  + umbrellaTargets
  + pluginTargets
  + testTargets

let package = Package(
  name: "InvariantSwift",
  platforms: packagePlatforms,
  products: packageProducts,
  dependencies: packageDependencies,
  targets: allTargets
)
