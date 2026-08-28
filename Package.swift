// swift-tools-version: 6.0
// Workspace manifest -- library sources live in subdirectories that also carry
// focused package manifests for local development.
//   Packages/InvariantSwiftCore   (core + generators + execution + advanced + domain)
//   Packages/InvariantSwiftMacros (macros + ghostwriter)
// The root package exports these libraries directly, similar to swift-syntax.
// swiftlint:disable all
import PackageDescription
import CompilerPluginSupport

// Swift 6 enables StrictConcurrency by default; no additional flags needed.
let commonSwiftSettings: [SwiftSetting] = []

let packagePlatforms: [SupportedPlatform] = [
  .iOS(.v17),
  .macOS(.v14),
  .tvOS(.v17),
  .watchOS(.v10),
  .macCatalyst(.v17),
]

// MARK: - Workspace Structure
// This package is the root workspace manifest.
// Nested manifests remain useful for focused work, but the root manifest exposes
// the publishable libraries directly from the workspace source directories.

let packageDependencies: [Package.Dependency] = [
  .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
  .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
  .package(url: "https://github.com/brunogama/MacroTemplateKit.git", exact: "0.0.6"),
  .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.19.4"),
]

// MARK: - Products

let packageProducts: [Product] = [
  // Core libraries
  .library(name: "InvariantSwiftCore", targets: ["InvariantSwiftCore"]),
  .library(name: "InvariantSwiftGenerators", targets: ["InvariantSwiftGenerators"]),
  .library(name: "InvariantSwiftExecution", targets: ["InvariantSwiftExecution"]),
  .library(name: "InvariantSwift", targets: ["InvariantSwift"]),
  .library(name: "InvariantSwiftAdvanced", targets: ["InvariantSwiftAdvanced"]),
  .library(name: "InvariantSwiftDomainGenerators", targets: ["InvariantSwiftDomainGenerators"]),
  // Macro API
  .library(name: "InvariantSwiftMacroAPI", targets: ["InvariantSwiftMacroAPI"]),
  // Umbrella library - re-exports everything from sub-packages
  .library(name: "InvariantSwiftUmbrella", targets: ["InvariantSwiftUmbrella"]),
  // Testing integration layer (core + macros + Swift Testing)
  .library(name: "InvariantSwiftTesting", targets: ["InvariantSwiftTesting"]),
  // Canonical command owner
  .executable(name: "invariant-cli", targets: ["invariant-cli"]),
  // Ghostwriter CLI for test generation and source analysis
  .executable(name: "GhostwriterCLI", targets: ["GhostwriterCLI"]),
  // Plugins
  .plugin(name: "InvariantSwiftPlugin", targets: ["InvariantSwiftPlugin"]),
  .plugin(name: "GhostwriterPlugin", targets: ["GhostwriterPlugin"]),
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

// MARK: - Macro Libraries

let macroTargets: [Target] = [
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
  .macro(
    name: "InvariantSwiftMacros",
    dependencies: [
      "InvariantSwiftExpansionSupport",
      .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax"),
    ],
    path: "Packages/InvariantSwiftMacros/Sources/InvariantSwiftMacros",
    swiftSettings: commonSwiftSettings
  ),
  .target(
    name: "InvariantSwiftMacroAPI",
    dependencies: [
      "InvariantSwiftMacros",
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
    ],
    path: "Packages/InvariantSwiftMacros/Sources/InvariantSwiftMacroAPI",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Umbrella Targets

let umbrellaTargets: [Target] = [

  // Full umbrella: re-exports core + macros
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
  ),

  // Testing integration layer (uses macros + core, exposes Swift Testing helpers)
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
  ),
]

// MARK: - Utility CLIs (remain in root)

let utilityTargets: [Target] = [
  .target(
    name: "InvariantCLIKit",
    dependencies: ["InvariantSwift", "GhostwriterLib"],
    path: "Sources/InvariantCLIKit",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "invariant-cli",
    dependencies: ["InvariantCLIKit"],
    path: "Sources/InvariantCLI",
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
      "InvariantSwiftCore",
      "InvariantSwift",
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
    dependencies: ["InvariantSwift"],
    path: "Sources/GeneratorCatalogCLI",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "CharacterizationCLI",
    dependencies: [],
    path: "Sources/CharacterizationCLI",
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
    dependencies: ["CharacterizationCLI"],
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

// MARK: - Integration Tests (remain in root, exercise workspace products)

let testTargets: [Target] = [
  .testTarget(
    name: "InvariantCLITests",
    dependencies: ["InvariantCLIKit", "invariant-cli"],
    path: "Tests/InvariantCLITests",
    resources: [.copy("Fixtures")],
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
    name: "MacroIntegrationTests",
    dependencies: [
      "GhostwriterCLI",
      "GhostwriterLib",
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
    ],
    path: "Packages/InvariantSwiftMacros/Tests/MacroIntegrationTests",
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

// MARK: - Package

let package = Package(
  name: "InvariantSwift",
  platforms: packagePlatforms,
  products: packageProducts,
  dependencies: packageDependencies,
  targets: coreTargets + macroTargets + umbrellaTargets + utilityTargets + pluginTargets
    + testTargets
)
