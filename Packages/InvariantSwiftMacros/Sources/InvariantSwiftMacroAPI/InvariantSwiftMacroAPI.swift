// InvariantSwiftMacroAPI
// Macro declarations only - NO swift-syntax dependency.
// These are the public-facing macro signatures that users import.

@_exported import InvariantSwiftCore
@_exported import InvariantSwift
@_exported import InvariantSwiftAdvanced

// This module provides macro declarations (not implementations):
// - @Property: Mark functions as property tests
// - @Arbitrary: Generate arbitrary instances
// - @DeriveGen: Derive generators automatically
// - @BusinessRule: Contract verification
// - @Regression: Regression test annotation
// - @Timeout: Test timeout control
// - @Idempotent, @Pure, @Equivalence: Algebraic law macros
//
// The actual macro implementations live in InvariantSwiftMacros
// which depends on swift-syntax and is only used at compile time.
