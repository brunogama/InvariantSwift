// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

// MARK: - InvariantSwiftMacros Package
//
// This package contains all SwiftSyntax-dependent macro implementations.
// It is isolated from the core library to provide faster build times for users
// who don't need macros. Users get 40-75% build time improvement from prebuilts.
//
// Architecture:
// - Layer 1: InvariantSwiftMacros (.macro) - SwiftSyntax macro implementations
// - Layer 2: InvariantSwiftMacroAPI (.target) - Public API for macro users
// - Layer 3: InvariantSwiftMacroTests (.testTarget) - Macro expansion tests

let commonSwiftSettings: [SwiftSetting] = [
  .unsafeFlags([
    "-Xfrontend", "-strict-concurrency=complete",
    "-Xfrontend", "-warn-concurrency",
  ]),
  .enableUpcomingFeature("StrictConcurrency"),
]

let packagePlatforms: [SupportedPlatform] = [
  .iOS(.v17),
  .macOS(.v14),
  .tvOS(.v17),
  .watchOS(.v10),
  .macCatalyst(.v17),
]

let package = Package(
  name: "InvariantSwiftMacros",
  platforms: packagePlatforms,
  products: [
    // Public API for macro users - re-exports macro declarations
    .library(
      name: "InvariantSwiftMacroAPI",
      targets: ["InvariantSwiftMacroAPI"]
    ),
    // Ghostwriter CLI for test generation
    .executable(
      name: "GhostwriterCLI",
      targets: ["GhostwriterCLI"]
    ),
  ],
  dependencies: [
    // SwiftSyntax 600.0.1 - Use this version for prebuilts compatibility
    // Prebuilts are only available for 600.0.1 and 601.0.1, NOT 602.0.0
    // This gives 40-75% build time improvement
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
    // Local dependency on InvariantSwiftCore for shared types
    .package(path: "../InvariantSwiftCore"),
  ],
  targets: [
    // MARK: - Layer 1: Macro Implementation (SwiftSyntax)
    // Compiler plugin that processes macro attributes at compile time
    .macro(
      name: "InvariantSwiftMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Sources/InvariantSwiftMacros",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 2: Macro API (Public Interface)
    // Client-facing API that re-exports macro declarations
    .target(
      name: "InvariantSwiftMacroAPI",
      dependencies: [
        "InvariantSwiftMacros",
        .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
        .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
        .product(name: "InvariantSwiftExperimental", package: "InvariantSwiftCore"),
      ],
      path: "Sources/InvariantSwiftMacroAPI",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 3: Ghostwriter (SwiftSyntax-based test generation)
    // Library for analyzing Swift source and generating property tests
    .target(
      name: "GhostwriterLib",
      dependencies: [
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
      ],
      path: "Sources/GhostwriterLib",
      swiftSettings: commonSwiftSettings
    ),

    // CLI executable for Ghostwriter
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

    // MARK: - Layer 4: Macro Tests
    .testTarget(
      name: "InvariantSwiftMacroTests",
      dependencies: [
        "InvariantSwiftMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
      ],
      path: "Tests/InvariantSwiftMacroTests",
      resources: [.copy("Resources")],
      swiftSettings: commonSwiftSettings
    ),
    .testTarget(
      name: "MacroIntegrationTests",
      dependencies: [
        "InvariantSwiftMacroAPI",
        "GhostwriterLib",
        .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
        .product(name: "InvariantSwiftExperimental", package: "InvariantSwiftCore"),
      ],
      path: "Tests/MacroIntegrationTests",
      swiftSettings: commonSwiftSettings
    ),
  ]
)
