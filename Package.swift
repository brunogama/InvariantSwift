// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "InvariantSwift",
  platforms: [
    .iOS(.v18),  // Required for latest TaskExecutor and Sendable APIs
    .macOS(.v15),  // Required for latest TaskExecutor and Sendable APIs
    .tvOS(.v18),
    .watchOS(.v11),
    .macCatalyst(.v18),
  ],
  products: [
    .library(
      name: "InvariantSwift",
      targets: ["InvariantSwift"]
    ),
    .executable(
      name: "functest",
      targets: ["FuncTestCLI"]
    ),
    .plugin(
      name: "FuncTestPlugin",
      targets: ["FuncTestPlugin"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
    .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"602.0.0"),
  ],
  targets: [
    // MARK: - Main Library Targets

    /// Main functional testing library target
    /// Configured for comprehensive code coverage analysis
    .target(
      name: "InvariantSwift",
      dependencies: [
        "InvariantSwiftMacros"
      ],
      path: "Sources/InvariantSwift",
      exclude: [
        "Macros/LawGeneration.swift.disabled"
      ],
      swiftSettings: [
        // Enable coverage collection for library code
        .unsafeFlags(
          [
            "-enable-testing",
            "-warnings-as-errors",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    /// Macro implementation target
    /// SwiftSyntax-based macro implementations for @PropertyTest
    .macro(
      name: "InvariantSwiftMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Sources/InvariantSwiftMacros",
      swiftSettings: [
        // Enable testing and strict warnings for macro code
        .unsafeFlags(
          [
            "-enable-testing",
            "-warnings-as-errors",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    // MARK: - CLI and Plugin Targets

    /// Command-line interface for property-based testing
    /// Provides integration with SPM and standalone CLI functionality
    .executableTarget(
      name: "FuncTestCLI",
      dependencies: [
        "InvariantSwift",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ],
      path: "Sources/FuncTestCLI",
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
            "-warnings-as-errors",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    /// Swift Package Manager Plugin for property-based testing integration
    /// Enables `swift package functest` command and build-time property testing
    .plugin(
      name: "FuncTestPlugin",
      capability: .command(
        intent: .custom(
          verb: "functest",
          description: "Run property-based tests with advanced features"
        ),
        permissions: [
          .writeToPackageDirectory(reason: "Generate test reports and coverage data"),
          .allowNetworkConnections(
            scope: .all(ports: []),
            reason: "Upload telemetry and coverage data"
          ),
        ]
      ),
      dependencies: [
        "FuncTestCLI"
      ],
      path: "Plugins/FuncTestPlugin"
    ),

    // MARK: - Comprehensive Test Coverage Targets

    /// Primary test target - covers core functionality, generators, properties
    /// Contains: PropertyTests, GeneratorCoreTests, CollectionGeneratorTests, DogfoodPropertyTests
    .testTarget(
      name: "FunctionalTesting",
      dependencies: ["InvariantSwift"],
      path: "Tests/FunctionalTesting",
      swiftSettings: [
        // Optimize for coverage collection
        .unsafeFlags(
          [
            "-enable-testing",
            "-warnings-as-errors",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    /// Macro-specific test target - covers macro expansion and error paths
    /// Contains: PropertyMacroTests with expansion, error handling, and syntax testing
    .testTarget(
      name: "InvariantSwiftMacroTests",
      dependencies: [
        "InvariantSwiftMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/InvariantSwiftMacroTests",
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
            "-warnings-as-errors",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    /// Performance and stress testing target
    /// Currently contains placeholder - can be used for performance regression testing
    .testTarget(
      name: "PerformanceTests",
      dependencies: ["InvariantSwift"],
      path: "Tests/PerformanceTests",
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
            "-Onone",  // Disable optimizations for accurate performance measurement
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    // MARK: - Coverage Analysis Integration Target

    /// Integration test target for coverage validation and reporting
    /// Contains utilities for coverage analysis and reporting
    .testTarget(
      name: "CoverageIntegrationTests",
      dependencies: [
        "InvariantSwift",
        "InvariantSwiftMacros",
      ],
      path: "Tests/CoverageIntegrationTests",
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
            "-warnings-as-errors",
          ],
          .when(configuration: .debug)
        )
      ]
    ),
  ]
)
