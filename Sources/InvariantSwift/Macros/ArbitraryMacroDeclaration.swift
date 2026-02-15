import InvariantSwift
import InvariantSwiftAdvanced
import InvariantSwiftCore
import Foundation
@attached(member, names: named(arbitrary), named(shrink))
@attached(extension, conformances: Generatable)
public macro Arbitrary(
  shrink: ArbitraryShrinkStrategy = .automatic,
  constraints: [String: String] = [:]
) = #externalMacro(module: "InvariantSwiftMacros", type: "ArbitraryMacro")

/// Shrinking strategy for @Arbitrary macro.
public enum ArbitraryShrinkStrategy: Sendable {
  case automatic
  case none
  case toEmpty
  case dropFields
}

// Generatable protocol is now in Core/Generatable.swift
