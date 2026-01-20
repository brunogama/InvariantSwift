/// InvariantSwift - Property-Based Testing Framework for Swift
///
/// This umbrella module re-exports all types from InvariantCore and adds
/// macro-based functionality. For a lighter dependency without SwiftSyntax,
/// import InvariantCore directly.
///
/// ## Usage
///
/// ```swift
/// import InvariantSwift  // Full framework with macros
/// // or
/// import InvariantCore   // Core only, no SwiftSyntax dependency
/// ```

// Re-export all public types from InvariantCore
@_exported import InvariantCore

// Macro declarations are provided by InvariantSwiftMacros
// which is linked as a dependency of InvariantSwift

// MARK: - Generatable Extensions (require Macros)

extension Seed: Generatable {
  /// Arbitrary generator for Seed values.
  /// Uses Gen<UInt64>.uint64 and maps to Seed init.
  public static var arbitrary: Gen<Seed> {
    Gen<UInt64>.uint64.map { Seed(value: $0) }
  }
}
