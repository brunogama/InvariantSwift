// swift-tools-version: 6.2
// Package.binary.swift -- Release manifest for binary macro distribution.
// On tagged releases, CI swaps this file to Package.swift so consumers resolve
// the pre-built macro while source-building the unified CLI and its tool dependencies.
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
  .executable(name: "invariant-cli", targets: ["invariant-cli"]),
  .plugin(name: "InvariantSwiftPlugin", targets: ["InvariantSwiftPlugin"]),
  .plugin(name: "GhostwriterPlugin", targets: ["GhostwriterPlugin"]),
  .plugin(name: "GeneratorCatalogPlugin", targets: ["GeneratorCatalogPlugin"]),
]

// SnapshotTesting supplies characterization storage and diffing.
let packageDependencies: [Package.Dependency] = [
  .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
  .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
  .package(url: "https://github.com/brunogama/MacroTemplateKit.git", exact: "0.0.6"),
  .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.18.9"),
]

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
      .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
    ],
    path: "Sources/InvariantSwiftTestingIntegration",
    resources: [.process("InvariantSwiftTesting.docc")],
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

// MARK: - Unified CLI

let utilityTargets: [Target] = [
  .target(
    name: "InvariantSwiftExpansionSupport",
    dependencies: [
      .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
      .product(name: "SwiftBasicFormat", package: "swift-syntax"),
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
    ],
    path: "Packages/InvariantSwiftMacros/Sources/InvariantSwiftExpansionSupport",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "GhostwriterLib",
    dependencies: [
      .product(name: "SwiftParser", package: "swift-syntax"),
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      "InvariantSwiftExpansionSupport",
    ],
    path: "Packages/InvariantSwiftMacros/Sources/GhostwriterLib",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantCLIKit",
    dependencies: ["InvariantSwift", "GhostwriterLib"],
    path: "Sources/InvariantCLIKit",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "invariant-cli",
    dependencies: [
      "InvariantCLIKit",
      .product(name: "SwiftBasicFormat", package: "swift-syntax"),
      .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
    ],
    path: "Sources/InvariantCLI",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "Benchmarks",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      .product(name: "Benchmark", package: "swift-benchmark"),
    ],
    path: "Benchmarks",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Plugins

let pluginTargets: [Target] = [
  .plugin(
    name: "InvariantSwiftPlugin",
    capability: .command(
      intent: .custom(verb: "invariant", description: "Run property-based tests"),
      permissions: [.writeToPackageDirectory(reason: "Generate test reports")]
    ),
    dependencies: ["invariant-cli"],
    path: "Plugins/InvariantSwiftPlugin"
  ),
  .plugin(
    name: "GhostwriterPlugin",
    capability: .command(
      intent: .custom(verb: "ghostwrite", description: "Generate property tests"),
      permissions: [.writeToPackageDirectory(reason: "Generate test files")]
    ),
    dependencies: ["invariant-cli"],
    path: "Plugins/GhostwriterPlugin"
  ),
  .plugin(
    name: "GeneratorCatalogPlugin",
    capability: .command(
      intent: .custom(verb: "browse-generators", description: "Browse generator catalog"),
      permissions: []
    ),
    dependencies: ["invariant-cli"],
    path: "Plugins/GeneratorCatalogPlugin"
  ),
]

// MARK: - Tests

let testTargets: [Target] = [
  .testTarget(
    name: "PluginIntegrationTests",
    dependencies: ["invariant-cli"],
    path: "Tests/PluginIntegrationTests",
    exclude: [
      "Fixtures/AdapterProbe/Package.swift",
      "Fixtures/PluginClient/Package.swift",
    ],
    resources: [.copy("Fixtures")],
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "InvariantCLITests",
    dependencies: ["InvariantCLIKit", "invariant-cli"],
    path: "Tests/InvariantCLITests",
    resources: [.copy("Fixtures")],
    swiftSettings: commonSwiftSettings
  ),
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
    resources: [.copy("Fixtures")],
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
  + utilityTargets
  + pluginTargets
  + testTargets

let package = Package(
  name: "InvariantSwift",
  platforms: packagePlatforms,
  products: packageProducts,
  dependencies: packageDependencies,
  targets: allTargets
)
