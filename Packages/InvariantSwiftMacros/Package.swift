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

// Swift 6 enables StrictConcurrency by default; no additional flags needed.
let commonSwiftSettings: [SwiftSetting] = []

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
    // Expansion support utilities - available for GhostwriterLib in root package
    .library(
      name: "InvariantSwiftExpansionSupport",
      targets: ["InvariantSwiftExpansionSupport"]
    ),
  ],
  dependencies: [
    // SwiftSyntax 602.0.0 - aligned with root workspace package version
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    // Template-driven declaration rendering for macro expansions
    .package(url: "https://github.com/brunogama/MacroTemplateKit.git", exact: "0.0.6"),
    // Local dependency on InvariantSwiftCore for shared types
    .package(path: "../InvariantSwiftCore"),
  ],
  targets: [
    .target(
      name: "InvariantSwiftExpansionSupport",
      dependencies: [
        .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
        .product(name: "SwiftBasicFormat", package: "swift-syntax"),
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
      ],
      path: "Sources/InvariantSwiftExpansionSupport",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 1: Macro Implementation (SwiftSyntax)
    // Compiler plugin that processes macro attributes at compile time
    .macro(
      name: "InvariantSwiftMacros",
      dependencies: [
        "InvariantSwiftExpansionSupport",
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Sources/InvariantSwiftMacros",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Ghostwriter (source generation from SwiftSyntax)
    // These sources live in this package, but only the root package declared
    // targets for them, so this package's own MacroIntegrationTests imported a
    // module that did not exist here and the test suite could not build.
    .target(
      name: "GhostwriterLib",
      dependencies: [
        "InvariantSwiftExpansionSupport",
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

    // MARK: - Layer 2: Macro API (Public Interface)
    // Client-facing API that re-exports macro declarations
    .target(
      name: "InvariantSwiftMacroAPI",
      dependencies: [
        "InvariantSwiftMacros",
        .product(name: "InvariantSwiftCore", package: "InvariantSwiftCore"),
        .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
        .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
      ],
      path: "Sources/InvariantSwiftMacroAPI",
      swiftSettings: commonSwiftSettings
    ),

    // MARK: - Layer 3: Macro Tests
    .testTarget(
      name: "InvariantSwiftMacroTests",
      dependencies: [
        "InvariantSwiftMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
        // For recording golden files: the same expansion assertMacroExpansion runs.
        .product(name: "SwiftParser", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
      ],
      path: "Tests/InvariantSwiftMacroTests",
      resources: [.copy("Resources")],
      swiftSettings: commonSwiftSettings
    ),
    .testTarget(
      name: "MacroIntegrationTests",
      dependencies: [
        "InvariantSwiftMacroAPI",
        // GhostwriterLib is imported by these tests; GhostwriterCLI is not, but
        // one test runs the built binary and skips when it is absent, so the
        // dependency is what makes that test actually run.
        "GhostwriterLib",
        "GhostwriterCLI",
        .product(name: "InvariantSwift", package: "InvariantSwiftCore"),
        .product(name: "InvariantSwiftAdvanced", package: "InvariantSwiftCore"),
      ],
      path: "Tests/MacroIntegrationTests",
      swiftSettings: commonSwiftSettings
    ),
  ]
)
