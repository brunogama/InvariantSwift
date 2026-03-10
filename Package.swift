// swift-tools-version: 6.0
// Umbrella manifest -- sources live in sub-packages.
//   Packages/InvariantSwiftCore  (core + generators + execution + advanced + domain)
//   Packages/InvariantSwiftMacros (macros + ghostwriter)
// Root targets: umbrella re-export, testing integration, utility CLIs, plugins, integration tests.
// swiftlint:disable all
import PackageDescription
import CompilerPluginSupport

let commonSwiftSettings: [SwiftSetting] = [
  .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete", "-Xfrontend", "-warn-concurrency"]),
  .enableUpcomingFeature("StrictConcurrency"),
]

let packagePlatforms: [SupportedPlatform] = [
  .iOS(.v17),
  .macOS(.v14),
  .tvOS(.v17),
  .watchOS(.v10),
  .macCatalyst(.v17),
]

// MARK: - Workspace Structure
// This package is the root umbrella of the monorepo workspace.
// Sub-packages:
//   - Packages/InvariantSwiftCore: Core library without SwiftSyntax dependency
//   - Packages/InvariantSwiftMacros: Macro implementations with SwiftSyntax

let packageDependencies: [Package.Dependency] = [
  .package(path: "Packages/InvariantSwiftCore"),
  .package(path: "Packages/InvariantSwiftMacros"),
  .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
  .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
]

// MARK: - Products

let packageProducts: [Product] = [
  // Umbrella library - re-exports everything from sub-packages
  .library(name: "InvariantSwiftUmbrella", targets: ["InvariantSwiftUmbrella"]),
  // Testing integration layer (core + macros + Swift Testing)
  .library(name: "InvariantSwiftTesting", targets: ["InvariantSwiftTesting"]),
  // Ghostwriter CLI for test generation and source analysis
  .executable(name: "GhostwriterCLI", targets: ["GhostwriterCLI"]),
  // Plugins
  .plugin(name: "InvariantSwiftPlugin", targets: ["InvariantSwiftPlugin"]),
  .plugin(name: "GhostwriterPlugin", targets: ["GhostwriterPlugin"]),
]

// MARK: - Umbrella Target

let umbrellaTargets: [Target] = [
  // Full umbrella: re-exports core + macros
  .target(
    name: "InvariantSwiftUmbrella",
    dependencies: [
      "InvariantSwiftTesting",
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftMacroAPI", package: "InvariantSwiftMacros"),
    ],
    path: "Sources/InvariantSwiftUmbrella",
    swiftSettings: commonSwiftSettings
  ),

  // Testing integration layer (uses macros + core, exposes Swift Testing helpers)
  .target(
    name: "InvariantSwiftTesting",
    dependencies: [
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftMacroAPI", package: "InvariantSwiftMacros"),
    ],
    path: "Sources/InvariantSwiftTestingIntegration",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Utility CLIs (remain in root)

let utilityTargets: [Target] = [
  .target(
    name: "GhostwriterLib",
    dependencies: [
      .product(name: "SwiftParser", package: "swift-syntax"),
      .product(name: "SwiftSyntax", package: "swift-syntax"),
      .product(name: "InvariantSwiftExpansionSupport", package: "InvariantSwiftMacros"),
    ],
    path: "Packages/InvariantSwiftMacros/Sources/GhostwriterLib",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "GhostwriterCLI",
    dependencies: [
      "GhostwriterLib",
      .product(name: "SwiftParser", package: "swift-syntax"),
      .product(name: "SwiftSyntax", package: "swift-syntax"),
    ],
    path: "Packages/InvariantSwiftMacros/Sources/GhostwriterCLI",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "Benchmarks",
    dependencies: [
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "Benchmark", package: "swift-benchmark"),
    ],
    path: "Benchmarks",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "PropertyTestHelper",
    dependencies: [],
    path: "Sources/PropertyTestHelper",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "GeneratorCatalogCLI",
    dependencies: [
      .product(name: "InvariantSwift", package: "InvariantSwiftCore")
    ],
    path: "Sources/GeneratorCatalogCLI",
    swiftSettings: commonSwiftSettings
  ),
  // FuncTestCLI: present in Sources/ but not yet exposed as a target (has pre-existing build issues)
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
  ),
  .plugin(
    name: "GhostwriterPlugin",
    capability: .command(
      intent: .custom(verb: "ghostwrite", description: "Generate property tests"),
      permissions: [.writeToPackageDirectory(reason: "Generate test files")]
    ),
    dependencies: ["GhostwriterCLI"],
    path: "Plugins/GhostwriterPlugin"
  ),
  .plugin(
    name: "GeneratorCatalogPlugin",
    capability: .command(
      intent: .custom(verb: "browse-generators", description: "Browse generator catalog"),
      permissions: []
    ),
    dependencies: ["GeneratorCatalogCLI"],
    path: "Plugins/GeneratorCatalogPlugin"
  ),
]

// MARK: - Integration Tests (remain in root, exercise sub-package products)

let testTargets: [Target] = [
  .testTarget(
    name: "CoverageIntegrationTests",
    dependencies: [
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
      "InvariantSwiftTesting",
    ],
    path: "Tests/CoverageIntegrationTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "GeneratedPropertyTests",
    dependencies: [
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
      "InvariantSwiftTesting",
    ],
    path: "Tests/GeneratedPropertyTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "MacroIntegrationTests",
    dependencies: [
      "GhostwriterCLI",
      "GhostwriterLib",
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
    ],
    path: "Packages/InvariantSwiftMacros/Tests/MacroIntegrationTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "SmokeTests",
    dependencies: [
      .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
      .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
      "InvariantSwiftTesting",
    ],
    path: "Tests/SmokeTests",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Package

let package = Package(
  name: "InvariantSwift",
  platforms: packagePlatforms,
  products: packageProducts,
  dependencies: packageDependencies,
  targets: umbrellaTargets + utilityTargets + pluginTargets + testTargets
)
