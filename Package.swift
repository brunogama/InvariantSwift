// swift-tools-version: 6.2
// swiftlint:disable all

import PackageDescription
import CompilerPluginSupport

let commonSwiftSettings: [SwiftSetting] = [
  .unsafeFlags(["-warnings-as-errors"]),
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
      name: "InvariantSwift",
      targets: ["InvariantSwift"]
    ),
    .library(
      name: "InvariantCore",
      targets: ["InvariantCore"]
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
  ],
  targets: [
    // MARK: - Core Library Target (No SwiftSyntax)

    /// Core property-based testing library without macro dependencies
    /// Use this target directly if you don't need macro support
    .target(
      name: "InvariantCore",
      dependencies: [],
      path: "Sources/InvariantSwift",
      exclude: [
        "Macros/LawGeneration.swift.disabled",
        "CLAUDE.md",
        "AGENTS.md",
        "Macros",  // Exclude macro-related code from Core
        "SwiftTesting",  // Has macro declarations (PropertyTestIntegration)
      ],
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    // MARK: - Main Library Targets

    /// Main functional testing library target (includes macros)
    /// Includes Core + Macros + SwiftTesting for full functionality
    .target(
      name: "InvariantSwift",
      dependencies: [
        "InvariantCore",
        "InvariantSwiftMacros",
      ],
      path: "Sources/InvariantSwift",
      exclude: [
        "Macros/LawGeneration.swift.disabled"
      ],
      sources: [
        "Macros",
        "SwiftTesting",
      ],
      swiftSettings: commonSwiftSettings + [
        .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
      ]
    ),

    /// Macro implementation target
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

    // MARK: - CLI and Plugin Targets

    /// Command-line interface for property-based testing
    .executableTarget(
      name: "FuncTestCLI",
      dependencies: [
        "InvariantSwift",
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

    // MARK: - Test Targets

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
        "InvariantSwiftMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/InvariantSwiftMacroTests",
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
  ]
)
