// swift-tools-version: 6.2
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

let packageProducts: [Product] = [
  .library(name: "InvariantSwiftCore", targets: ["InvariantSwiftCore"]),
  .library(name: "InvariantSwift", targets: ["InvariantSwift"]),
  .library(name: "InvariantSwiftTesting", targets: ["InvariantSwiftTesting"]),
  .library(name: "InvariantSwiftExperimental", targets: ["InvariantSwiftExperimental"]),
  .library(name: "InvariantSwiftDomainGenerators", targets: ["InvariantSwiftDomainGenerators"]),
  .plugin(name: "InvariantSwiftPlugin", targets: ["InvariantSwiftPlugin"]),
  .plugin(name: "GhostwriterPlugin", targets: ["GhostwriterPlugin"]),
]

let packageDependencies: [Package.Dependency] = [
  .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
  .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
]

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
      // Directories that are now in dedicated modules:
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
      "InvariantSwiftExperimental",
      "InvariantSwiftMacros",
    ],
    path: "Sources/InvariantSwiftMacroAPI",
    swiftSettings: commonSwiftSettings
  )
]

let experimentalTargets: [Target] = [
  .target(
    name: "InvariantSwiftExperimental",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
    ],
    path: "Sources/InvariantSwiftExperimental",
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
      "InvariantSwiftExperimental",
      "InvariantSwiftMacroAPI",
      "InvariantSwiftMacros",
    ],
    path: "Sources/InvariantSwiftTestingIntegration",
    swiftSettings: commonSwiftSettings
  )
]

// MARK: - Compile-Time Only (swift-syntax isolated)

let macroTargets: [Target] = [
  .macro(
    name: "InvariantSwiftMacros",
    dependencies: [
      .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax"),
    ],
    path: "Sources/InvariantSwiftMacros",
    exclude: ["CLAUDE.md", "AGENTS.md"],
    swiftSettings: commonSwiftSettings
  )
]

let ghostwriterTargets: [Target] = [
  .target(
    name: "GhostwriterLib",
    dependencies: [
      .product(name: "SwiftParser", package: "swift-syntax"),
      .product(name: "SwiftSyntax", package: "swift-syntax"),
    ],
    path: "Sources/GhostwriterLib",
    swiftSettings: commonSwiftSettings
  ),
  .executableTarget(
    name: "GhostwriterCLI",
    dependencies: [
      "GhostwriterLib",
      .product(name: "SwiftParser", package: "swift-syntax"),
      .product(name: "SwiftSyntax", package: "swift-syntax"),
    ],
    path: "Sources/GhostwriterCLI",
    swiftSettings: commonSwiftSettings
  ),
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

let utilityTargets: [Target] = [
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
      "InvariantSwiftExperimental",
      "GhostwriterLib",
    ],
    path: "Tests/InvariantSwiftTests",
    swiftSettings: commonSwiftSettings
  ),
  .testTarget(
    name: "InvariantSwiftMacroTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwiftMacros",
      .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
    ],
    path: "Tests/InvariantSwiftMacroTests",
    resources: [.copy("Resources")],
    swiftSettings: commonSwiftSettings
  ),
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
      "InvariantSwiftExperimental",
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
      "InvariantSwiftExperimental",
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
      "InvariantSwiftExperimental",
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
  + ghostwriterTargets
  + domainTargets
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
