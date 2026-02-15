/// InvariantSwiftUmbrella - Unified Re-export Module
///
/// This umbrella module re-exports all public types from both the core library
/// and the macro API, providing a single import for the full framework.
///
/// ## Package Architecture
///
/// InvariantSwift uses a monorepo workspace structure:
/// - `InvariantSwiftCore`: Core library without SwiftSyntax dependency
/// - `InvariantSwiftMacros`: Macro implementations requiring SwiftSyntax
///
/// ## Usage
///
/// ```swift
/// // Import everything (core + macros)
/// import InvariantSwiftUmbrella
///
/// // Or import sub-packages directly:
/// import InvariantSwiftCore       // Core only, no SwiftSyntax
/// import InvariantSwiftMacroAPI   // Macro declarations
/// ```

// Re-export core library types
@_exported import InvariantSwift
@_exported import InvariantSwiftCore

// Re-export macro API for macro declarations
@_exported import InvariantSwiftMacroAPI
