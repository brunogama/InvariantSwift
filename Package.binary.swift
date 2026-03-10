// swift-tools-version: 6.2
// Package.binary.swift -- Release manifest for binary macro distribution.
// On tagged releases, CI swaps this file to Package.swift so consumers
// resolve the pre-built InvariantSwiftMacros plugin without swift-syntax.
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
  .library(name: "InvariantSwiftUmbrella", targets: ["InvariantSwiftUmbrella"]),
  .library(name: "InvariantSwiftCore", targets: ["InvariantSwiftCore"]),
  .library(name: "InvariantSwift", targets: ["InvariantSwift"]),
  .library(name: "InvariantSwiftTesting", targets: ["InvariantSwiftTesting"]),
  .library(name: "InvariantSwiftAdvanced", targets: ["InvariantSwiftAdvanced"]),
  .library(name: "InvariantSwiftDomainGenerators", targets: ["InvariantSwiftDomainGenerators"]),
  .plugin(name: "InvariantSwiftPlugin", targets: ["InvariantSwiftPlugin"]),
  // Note: GhostwriterPlugin excluded -- depends on GhostwriterCLI which requires swift-syntax.
]

// No swift-syntax, no swift-benchmark in the binary manifest.
let packageDependencies: [Package.Dependency] = []

// MARK: - Layer 0: Foundation (zero dependencies)

let coreTargets: [Target] = [
  .target(
    name: "InvariantSwiftCore",
    dependencies: [],
    path: "Sources/InvariantSwiftCore",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Layer 1: Building Blocks (depend only on Core)

let generatorTargets: [Target] = [
  .target(
    name: "InvariantSwiftGenerators",
    dependencies: ["InvariantSwiftCore"],
    path: "Sources/InvariantSwiftGenerators",
    swiftSettings: commonSwiftSettings
  )
]

let executionTargets: [Target] = [
  .target(
    name: "InvariantSwiftExecution",
    dependencies: ["InvariantSwiftCore"],
    path: "Sources/InvariantSwiftExecution",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Layer 2: Main Library (combines internal modules)

let libraryTargets: [Target] = [
  .target(
    name: "InvariantSwift",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwiftGenerators",
      "InvariantSwiftExecution",
    ],
    path: "Sources/InvariantSwift",
    exclude: [
      "Core",
      "Generators",
      "Testing",
      "Contract",
      "Database",
      "Advanced",
      "Coverage",
      "Extensions",
      "Fuzzing",
      "Reliability",
      "Observability",
      "SwiftTesting",
      "Macros",
      "CLAUDE.md",
      "AGENTS.md",
    ],
    sources: [
      "Differential",
      "Ghostwriter",
      "Presentation",
      "FunctionalTesting.swift",
      "InvariantSwift.swift",
    ],
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Layer 3: Extensions (depend on main library)

let macroAPITargets: [Target] = [
  .target(
    name: "InvariantSwiftMacroAPI",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
      "InvariantSwiftMacros",
    ],
    path: "Sources/InvariantSwiftMacroAPI",
    swiftSettings: commonSwiftSettings
  )
]

let experimentalTargets: [Target] = [
  .target(
    name: "InvariantSwiftAdvanced",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
    ],
    path: "Sources/InvariantSwiftAdvanced",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Layer 4: Testing Integration (depends on everything)

let testingIntegrationTargets: [Target] = [
  .target(
    name: "InvariantSwiftTesting",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftAdvanced",
      "InvariantSwiftMacroAPI",
      "InvariantSwiftMacros",
    ],
    path: "Sources/InvariantSwiftTestingIntegration",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Compile-Time Only (pre-built binary)

let macroTargets: [Target] = [
  // Pre-built macro plugin binary.
  // The executable name matches #externalMacro(module: "InvariantSwiftMacros", ...)
  // in InvariantSwiftMacroAPI declaration files.
  .binaryTarget(
    name: "InvariantSwiftMacros",
    url:
      "https://github.com/brunogama/InvariantSwift/releases/download/__VERSION__/InvariantSwiftMacros.artifactbundle.zip",
    checksum: "__CHECKSUM__"
  )
]

// Note: GhostwriterLib, GhostwriterCLI, and GhostwriterPlugin are excluded
// from the binary manifest because they depend directly on swift-syntax.

// MARK: - Umbrella (re-exports from sub-packages)

let umbrellaTargets: [Target] = [
  .target(
    name: "InvariantSwiftUmbrella",
    dependencies: [
      "InvariantSwift",
      "InvariantSwiftCore",
      "InvariantSwiftMacroAPI",
    ],
    path: "Sources/InvariantSwiftUmbrella",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Domain & Utilities

let domainTargets: [Target] = [
  .target(
    name: "InvariantSwiftDomainGenerators",
    dependencies: ["InvariantSwiftCore", "InvariantSwift"],
    path: "Sources/InvariantSwiftDomainGenerators",
    swiftSettings: commonSwiftSettings
  )
]

// Note: Benchmarks, PropertyTestHelper, GeneratorCatalogCLI excluded from
// binary manifest (Benchmarks depends on swift-benchmark; others are dev tools).

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
  // GhostwriterPlugin excluded -- depends on GhostwriterCLI (swift-syntax).
  // GeneratorCatalogPlugin excluded -- depends on GeneratorCatalogCLI (dev tool).
]

// MARK: - Tests

let testTargets: [Target] = [
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
      "InvariantSwiftMacros",
      "InvariantSwiftTesting",
      "InvariantSwiftAdvanced",
    ],
    path: "Tests/InvariantSwiftTests",
    swiftSettings: commonSwiftSettings
  ),
  // InvariantSwiftMacroTests excluded -- depends on SwiftSyntaxMacrosTestSupport.
  .testTarget(
    name: "InvariantSwiftDomainGeneratorsTests",
    dependencies: ["InvariantSwiftDomainGenerators", "InvariantSwift"],
    path: "Tests/InvariantSwiftDomainGeneratorsTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "PerformanceTests",
    dependencies: ["InvariantSwift"],
    path: "Tests/PerformanceTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "CoverageIntegrationTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftMacros",
      "InvariantSwiftTesting",
      "InvariantSwiftAdvanced",
    ],
    path: "Tests/CoverageIntegrationTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "GeneratedPropertyTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftMacros",
      "InvariantSwiftTesting",
      "InvariantSwiftAdvanced",
    ],
    path: "Tests/GeneratedPropertyTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "SmokeTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftMacros",
      "InvariantSwiftTesting",
      "InvariantSwiftAdvanced",
    ],
    path: "Tests/SmokeTests",
    swiftSettings: commonSwiftSettings
  ),
]

// MARK: - Package

let allTargets =
  coreTargets
  + generatorTargets
  + executionTargets
  + libraryTargets
  + macroAPITargets
  + experimentalTargets
  + testingIntegrationTargets
  + macroTargets
  + umbrellaTargets
  + domainTargets
  + pluginTargets
  + testTargets

let package = Package(
  name: "InvariantSwift",
  platforms: packagePlatforms,
  products: packageProducts,
  dependencies: packageDependencies,
  targets: allTargets
)
