// swift-tools-version: 6.2
// swiftlint:disable all

import PackageDescription
import CompilerPluginSupport

let commonSwiftSettings: [SwiftSetting] = [
  // .unsafeFlags(["-warnings-as-errors"]),
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
  .library(
    name: "InvariantSwiftCore",
    targets: ["InvariantSwiftCore"]
  ),
  .library(
    name: "InvariantSwift",
    targets: ["InvariantSwift"]
  ),
  // Note: InvariantSwiftMacros is a .macro target, not a library
  .library(
    name: "InvariantSwiftTesting",
    targets: ["InvariantSwiftTesting"]
  ),
  .library(
    name: "InvariantSwiftExperimental",
    targets: ["InvariantSwiftExperimental"]
  ),
  .library(
    name: "InvariantSwiftDomainGenerators",
    targets: ["InvariantSwiftDomainGenerators"]
  ),
  // NOTE: FuncTestCLI temporarily disabled - needs type inference fixes
  // .executable(
  //   name: "FuncTestCLI",
  //   targets: ["FuncTestCLI"]
  // ),
  .plugin(
    name: "InvariantSwiftPlugin",
    targets: ["InvariantSwiftPlugin"]
  ),
  .plugin(
    name: "GhostwriterPlugin",
    targets: ["GhostwriterPlugin"]
  ),
]

let packageDependencies: [Package.Dependency] = [
  .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
  .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
]

let coreTargets: [Target] = [
  .target(
    name: "InvariantSwiftCore",
    dependencies: [],
    path: "Sources/InvariantSwift",
    exclude: [
      "Contract",
      "Database",
      "Differential",
      "Generators",
      "Ghostwriter",
      "Persistence",
      "Presentation",
      "Testing",
      "Advanced",
      "Coverage",
      "Fuzzing",
      "Reliability",
      "Observability",
      "SwiftTesting",
      "Macros",
      "FunctionalTesting.swift",
      "CLAUDE.md",
      "AGENTS.md",
    ],
    sources: [
      "Core"
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  )
]

let libraryTargets: [Target] = [
  .target(
    name: "InvariantSwift",
    dependencies: [
      "InvariantSwiftCore"
    ],
    path: "Sources/InvariantSwift",
    exclude: [
      "Core",  // InvariantSwiftCore
      "Advanced",  // InvariantSwiftExperimental
      "Coverage",  // InvariantSwiftExperimental
      "Fuzzing",  // InvariantSwiftExperimental
      "Reliability",  // InvariantSwiftExperimental
      "Observability",  // InvariantSwiftExperimental
      "SwiftTesting",  // InvariantSwiftTesting
      "Macros",  // InvariantSwiftTesting
      "CLAUDE.md",
      "AGENTS.md",
    ],
    sources: [
      "Contract",
      "Database",
      "Differential",
      "Generators",
      "Ghostwriter",
      "Persistence",
      "Presentation",
      "Testing",
      "FunctionalTesting.swift",
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
  .macro(
    name: "InvariantSwiftMacros",
    dependencies: [
      .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
      .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      .product(name: "SwiftParser", package: "swift-syntax"),
    ],
    path: "Sources/InvariantSwiftMacros",
    exclude: [
      "CLAUDE.md",
      "AGENTS.md",
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
  .target(
    name: "InvariantSwiftTesting",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
      "InvariantSwiftExperimental",
      "InvariantSwiftMacros",
    ],
    path: "Sources/InvariantSwift",
    exclude: [
      "Core",
      "Contract",
      "Database",
      "Differential",
      "Generators",
      "Ghostwriter",
      "Persistence",
      "Presentation",
      "Testing",
      "Advanced",
      "Coverage",
      "Fuzzing",
      "Reliability",
      "Observability",
      "FunctionalTesting.swift",
      "Macros/LawGeneration.swift.disabled",
      "CLAUDE.md",
      "AGENTS.md",
    ],
    sources: [
      "SwiftTesting",
      "Macros",
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
  .target(
    name: "InvariantSwiftExperimental",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
    ],
    path: "Sources/InvariantSwift",
    exclude: [
      "Core",
      "Contract",
      "Database",
      "Differential",
      "Generators",
      "Ghostwriter",
      "Persistence",
      "Presentation",
      "Testing",
      "SwiftTesting",
      "Macros",
      "FunctionalTesting.swift",
      "CLAUDE.md",
      "AGENTS.md",
    ],
    sources: [
      "Advanced",
      "Coverage",
      "Fuzzing",
      "Reliability",
      "Observability",
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
  .target(
    name: "InvariantSwiftDomainGenerators",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwift",
    ],
    path: "Sources/InvariantSwiftDomainGenerators",
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
]

let executableTargets: [Target] = [
  // NOTE: FuncTestCLI temporarily disabled - needs type inference fixes
  // .executableTarget(
  //   name: "FuncTestCLI",
  //   dependencies: [
  //     "InvariantSwift",
  //     "InvariantSwiftTesting",
  //     .product(name: "CustomDump", package: "swift-custom-dump"),
  //   ],
  //   path: "Sources/FuncTestCLI",
  //   swiftSettings: commonSwiftSettings + [
  //     .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
  //   ]
  // ),
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

let pluginTargets: [Target] = [
  .plugin(
    name: "InvariantSwiftPlugin",
    capability: .command(
      intent: .custom(
        verb: "invariant",
        description: "Run property-based tests with advanced features"
      ),
      permissions: [
        .writeToPackageDirectory(reason: "Generate test reports and local artifacts")
      ]
    ),
    dependencies: [
      // "FuncTestCLI"  // Temporarily disabled
    ],
    path: "Plugins/InvariantSwiftPlugin"
  ),
  .plugin(
    name: "GhostwriterPlugin",
    capability: .command(
      intent: .custom(
        verb: "ghostwrite",
        description: "Generate property tests automatically from source code"
      ),
      permissions: [
        .writeToPackageDirectory(reason: "Generate property test files")
      ]
    ),
    dependencies: [
      "GhostwriterCLI"
    ],
    path: "Plugins/GhostwriterPlugin"
  ),
  .plugin(
    name: "GeneratorCatalogPlugin",
    capability: .command(
      intent: .custom(
        verb: "browse-generators",
        description: "Browse the generator catalog interactively"
      ),
      permissions: []
    ),
    dependencies: [
      "GeneratorCatalogCLI"
    ],
    path: "Plugins/GeneratorCatalogPlugin"
  ),
]

let testTargets: [Target] = [
  .testTarget(
    name: "InvariantSwiftDomainGeneratorsTests",
    dependencies: [
      "InvariantSwiftDomainGenerators",
      "InvariantSwift",
    ],
    path: "Tests/InvariantSwiftDomainGeneratorsTests",
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
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
    exclude: [
      "FunctionalTesting/CollectionShrinkingV2Tests.swift.disabled",
      "FunctionalTesting/SMTSolverTests.swift.disabled",
      "FunctionalTesting/LensSystemTests.swift.disabled",
      "FunctionalTesting/NumericGeneratorTests.swift.disabled",
      "FunctionalTesting/CollectionGeneratorTests.swift.disabled",
      "FunctionalTesting/LinearizabilityTests.swift.disabled",
      "FunctionalTesting/FailurePersistenceTests.swift.disabled",
      "FunctionalTesting/MetaPropertyTests.swift.disabled",
      "FunctionalTesting/LibFuzzerTests.swift.disabled",
      "FunctionalTesting/MetamorphicTests.swift.disabled",
      "FunctionalTesting/CoverageCompletionTests.swift.disabled",
      "FunctionalTesting/CoverageGuidedTests.swift.disabled",
      "FunctionalTesting/FloatingPointModeTests.swift.disabled",
      "FunctionalTesting/PrettyPrinterEnhancementTests.swift.disabled",
      "FunctionalTesting/GeneratorRegistryTests.swift.disabled",
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
  .testTarget(
    name: "InvariantSwiftMacroTests",
    dependencies: [
      "InvariantSwiftCore",
      "InvariantSwiftMacros",
      .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
    ],
    path: "Tests/InvariantSwiftMacroTests",
    resources: [
      .copy("Resources")
    ],
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
  .testTarget(
    name: "PerformanceTests",
    dependencies: ["InvariantSwift"],
    path: "Tests/PerformanceTests",
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing", "-Onone"], .when(configuration: .debug))
    ]
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
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
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
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
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
    swiftSettings: commonSwiftSettings + [
      .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
    ]
  ),
]

let allTargets = coreTargets + libraryTargets + executableTargets + pluginTargets + testTargets

let package = Package(
  name: "InvariantSwift",
  platforms: packagePlatforms,
  products: packageProducts,
  dependencies: packageDependencies,
  targets: allTargets
)
