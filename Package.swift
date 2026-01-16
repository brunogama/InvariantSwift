// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "InvariantSwift",
  platforms: [
    .iOS(.v18),
    .macOS(.v15),
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
    // Pin to 600.0.1 for Swift 6.0.x/6.1.x/6.2.x compatibility
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
  ],
  targets: [
    // MARK: - Main Library Targets

    /// Main functional testing library target
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
        .unsafeFlags(
          [
            "-enable-testing",
          ],
          .when(configuration: .debug)
        )
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
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
          ],
          .when(configuration: .debug)
        )
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
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    /// Swift Package Manager Plugin
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

    // MARK: - Test Targets

    .testTarget(
      name: "FunctionalTesting",
      dependencies: ["InvariantSwift"],
      path: "Tests/FunctionalTesting",
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

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
          ],
          .when(configuration: .debug)
        )
      ]
    ),

    .testTarget(
      name: "PerformanceTests",
      dependencies: ["InvariantSwift"],
      path: "Tests/PerformanceTests",
      swiftSettings: [
        .unsafeFlags(
          [
            "-enable-testing",
            "-Onone",
          ],
          .when(configuration: .debug)
        )
      ]
    ),

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
          ],
          .when(configuration: .debug)
        )
      ]
    ),
  ]
)
