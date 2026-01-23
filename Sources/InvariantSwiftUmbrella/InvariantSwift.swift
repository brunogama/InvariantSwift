/// InvariantSwift - Property-Based Testing Framework for Swift
///
/// This umbrella module re-exports all types from InvariantCore and adds
/// macro-based functionality. For a lighter dependency without SwiftSyntax,
/// import InvariantSwiftCore directly.
///
/// ## Usage
///
/// ```swift
/// import InvariantSwift  // Full framework with macros
/// // or
/// import InvariantSwiftCore   // Core only, no SwiftSyntax dependency
/// ```

// Re-export all public types from InvariantCore
@_exported import InvariantSwiftCore

// Macro declarations are provided by InvariantSwiftMacros
// which is linked as a dependency of InvariantSwift
// Seed: Generatable is now in Core/Seed.swift
