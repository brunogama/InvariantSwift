// swift-tools-version: 6.2
// swiftlint:disable all

import PackageDescription
import CompilerPluginSupport

let commonSwiftSettings: [SwiftSetting] = [
  // .unsafeFlags(["-warnings-as-errors"]),
  .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete", "-Xfrontend", "-warn-concurrency"]),
  .enableUpcomingFeature("StrictConcurrency"),
]

let package = Package(
  name: "InvariantSwift",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .tvOS(.v17),
    .watchOS(.v10),
    .macCatalyst(.v17),
  ],
  products: [
    .library(
      name: "InvariantSwiftCore",
      targets: ["InvariantSwiftCore"]
    ),
    .library(
      name: "InvariantSwift",
      targets: ["InvariantSwift"]
    ),
    .library(
      name: "InvariantSwiftMacros",
      targets: ["InvariantSwiftMacros"]
    ),
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
    .executable(
      name: "FuncTestCLI",
      targets: ["FuncTestCLI"]
    ),
    .plugin(
      name: "InvariantSwiftPlugin",
      targets: ["InvariantSwiftPlugin"]
    ),
    .plugin(
      name: "GhostwriterPlugin",
      targets: ["GhostwriterPlugin"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(url: "https://github.com/swiftlang/swift-syntax", exact: "602.0.0"),
    .package(url: "https://github.com/google/swift-benchmark", from: "0.1.2"),
  ],
  targets: [
    // MARK: - Core Library Target (No SwiftSyntax)

    /// Core property-based testing primitives: Gen, ShrinkTree, Property, ReplayToken, FailureReport
    .target(
      name: "InvariantSwiftCore",
      dependencies: [],
      path: "Sources/InvariantSwift",
      sources: [
        "Core"
      ],
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    // MARK: - Main Library Targets

    /// Main functional testing library: re-exports core + stable generator set
    .target(
      name: "InvariantSwift",
      dependencies: [
        "InvariantSwiftCore"
      ],
      path: "Sources/InvariantSwift",
      sources: [
        "Generators",  // Stable generators
        "Presentation",  // Pretty printing, shrinking traces
        "Persistence",  // Failing examples, example database
        "FunctionalTesting.swift",  // Main exports
      ],
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    /// Macro implementation target (build-time only)
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

    /// Swift Testing adapters and integration
    .target(
      name: "InvariantSwiftTesting",
      dependencies: [
        "InvariantSwiftCore",
        "InvariantSwiftMacros",
      ],
      path: "Sources/InvariantSwift",
      sources: [
        "SwiftTesting",  // Testing framework adapters
        "Macros",  // Macro declarations that depend on SwiftTesting
      ],
      exclude: [
        "Macros/LawGeneration.swift.disabled"
      ],
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    /// Experimental features: coverage-guided, SMT, linearizability, etc.
    .target(
      name: "InvariantSwiftExperimental",
      dependencies: [
        "InvariantSwiftCore"
      ],
      path: "Sources/InvariantSwift",
      sources: [
        "Advanced",  // SMT, linearizability, coverage-guided, DICE
        "Coverage",  // Coverage analysis
        "Fuzzing",  // LibFuzzer integration
        "Reliability",  // Flake hunter, regression bank
        "Observability",  // Telemetry system
      ],
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    // MARK: - Domain Generators Target

    /// Domain-specific generators (Email, Address, etc.)
    /// Optional target to avoid bloating core
    .target(
      name: "InvariantSwiftDomainGenerators",
      dependencies: [
        "InvariantSwiftCore"
      ],
      path: "Sources/InvariantSwiftDomainGenerators",
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    // MARK: - CLI and Plugin Targets

    /// Command-line interface for property-based testing
    .executableTarget(
      name: "FuncTestCLI",
      dependencies: [
        "InvariantSwift",
        "InvariantSwiftTesting",  // For Swift Testing integration
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ],
      path: "Sources/FuncTestCLI",
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    /// Swift Package Manager Plugin
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
        "FuncTestCLI"
      ],
      path: "Plugins/InvariantSwiftPlugin"
    ),

    /// Ghostwriter Plugin for automatic test generation
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

    /// Ghostwriter CLI - SwiftSyntax-powered source analysis
    .executableTarget(
      name: "GhostwriterCLI",
      dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ],
      path: "Sources/GhostwriterCLI",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Benchmark Target

    /// Performance benchmarks using google/swift-benchmark
    .executableTarget(
      name: "Benchmarks",
      dependencies: [
        "InvariantSwiftCore",
        .product(name: "Benchmark", package: "swift-benchmark"),
      ],
      path: "Benchmarks",
      swiftSettings: commonSwiftSettings
    ),

    /// Property test helper for subprocess crash isolation (macOS only)
    .executableTarget(
      name: "PropertyTestHelper",
      dependencies: [],
      path: "Sources/PropertyTestHelper",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Test Targets

    .testTarget(
      name: "InvariantSwiftDomainGeneratorsTests",
      dependencies: [
        "InvariantSwiftDomainGenerators",
        "InvariantSwift",  // For Property testing support
      ],
      path: "Tests/InvariantSwiftDomainGeneratorsTests",
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    .testTarget(
      name: "FunctionalTesting",
      dependencies: ["InvariantSwift"],
      path: "Tests/FunctionalTesting",
      exclude: ["FakeryGeneratorsTests.swift.disabled"],
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
      exclude: [
        "Resources"
      ],
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
        "InvariantSwift",
        "InvariantSwiftMacros",
      ],
      path: "Tests/CoverageIntegrationTests",
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    .testTarget(
      name: "GeneratedPropertyTests",
      dependencies: ["InvariantSwift"],
      path: "Tests/Generated",
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    // MARK: - Smoke Tests

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
)
