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
        )
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
            ],
            path: "Tests/InvariantSwiftMacroTests",
            resources: [.copy("Resources")],
            swiftSettings: commonSwiftSettings
        ),
    ]
)
