// ShrinkPredicates.swift
// InvariantSwift
//
// Custom shrinking rules and predicates.
// Implements Task 1.13 from the roadmap.

import Foundation
import InvariantSwiftCore

// MARK: - Shrink Predicate Protocol

/// A predicate that controls shrinking behavior for a generator.
///
/// Shrink predicates allow fine-grained control over how values shrink,
/// enabling domain-specific shrinking strategies that preserve important
/// properties while finding minimal counterexamples.
///
/// ## Example Usage
///
/// ```swift
/// // Shrink toward zero, but keep sign
/// let preserveSign = ShrinkPredicate<Int> { original, candidate in
///     (original >= 0) == (candidate >= 0)
/// }
///
/// // Shrink array but keep at least one element
/// let nonEmpty = ShrinkPredicate<[Int]> { _, candidate in
///     !candidate.isEmpty
/// }
/// ```
public struct ShrinkPredicate<T>: Sendable where T: Sendable {
  /// The predicate function.
  ///
  /// - Parameters:
  ///   - original: The original value being shrunk.
  ///   - candidate: A proposed shrunk value.
  /// - Returns: True if the candidate is a valid shrink.
  public let isValid: @Sendable (T, T) -> Bool

  /// Creates a shrink predicate from a validation function.
  ///
  /// - Parameter isValid: Function that validates shrink candidates.
  public init(isValid: @escaping @Sendable (T, T) -> Bool) {
    self.isValid = isValid
  }

  /// Creates a shrink predicate from a simple constraint.
  ///
  /// - Parameter constraint: A constraint that must hold for shrunk values.
  public init(constraint: @escaping @Sendable (T) -> Bool) {
    self.isValid = { _, candidate in constraint(candidate) }
  }

  /// Validates whether a candidate is a valid shrink of the original.
  public func validate(original: T, candidate: T) -> Bool {
    isValid(original, candidate)
  }
}

// MARK: - Built-in Predicates

extension ShrinkPredicate {
  /// A predicate that accepts all candidates (no filtering).
  public static var all: ShrinkPredicate<T> {
    ShrinkPredicate { _, _ in true }
  }

  /// A predicate that rejects all candidates (no shrinking).
  public static var none: ShrinkPredicate<T> {
    ShrinkPredicate { _, _ in false }
  }
}

extension ShrinkPredicate where T: Equatable {
  /// A predicate that rejects shrinking to the same value.
  public static var notEqual: ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      original != candidate
    }
  }
}

extension ShrinkPredicate where T: Comparable {
  /// A predicate that ensures shrunk values are smaller.
  public static var smaller: ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      candidate < original
    }
  }

  /// A predicate that ensures shrunk values are within bounds.
  ///
  /// - Parameter bounds: The allowed range for shrunk values.
  public static func inBounds(_ bounds: ClosedRange<T>) -> ShrinkPredicate<T> {
    ShrinkPredicate { _, candidate in
      bounds.contains(candidate)
    }
  }
}

extension ShrinkPredicate where T: SignedNumeric & Comparable {
  /// A predicate that preserves the sign of numeric values.
  public static var preserveSign: ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      (original >= 0 && candidate >= 0) || (original < 0 && candidate < 0)
    }
  }

  /// A predicate that shrinks toward zero while preserving sign.
  public static var towardZeroPreservingSign: ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      // Must preserve sign
      guard (original >= 0) == (candidate >= 0) else { return false }
      // Must be closer to zero (or equal)
      if original >= 0 {
        return candidate <= original
      } else {
        return candidate >= original
      }
    }
  }
}

extension ShrinkPredicate where T: Collection {
  /// A predicate that ensures collections stay non-empty.
  public static var nonEmpty: ShrinkPredicate<T> {
    ShrinkPredicate { _, candidate in
      !candidate.isEmpty
    }
  }

  /// A predicate that limits maximum shrink reduction.
  ///
  /// - Parameter maxReduction: Maximum number of elements to remove.
  public static func maxReduction(_ maxReduction: Int) -> ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      original.count - candidate.count <= maxReduction
    }
  }

  /// A predicate that ensures minimum collection length.
  ///
  /// - Parameter minLength: Minimum allowed length.
  public static func minLength(_ minLength: Int) -> ShrinkPredicate<T> {
    ShrinkPredicate { _, candidate in
      candidate.count >= minLength
    }
  }
}

extension ShrinkPredicate where T == String {
  /// A predicate that ensures strings stay non-empty.
  public static var nonEmptyString: ShrinkPredicate<String> {
    ShrinkPredicate { _, candidate in
      !candidate.isEmpty
    }
  }

  /// A predicate that preserves string prefix.
  ///
  /// - Parameter prefix: The prefix to preserve.
  public static func preservePrefix(_ prefix: String) -> ShrinkPredicate<String> {
    ShrinkPredicate { _, candidate in
      candidate.hasPrefix(prefix)
    }
  }

  /// A predicate that preserves string suffix.
  ///
  /// - Parameter suffix: The suffix to preserve.
  public static func preserveSuffix(_ suffix: String) -> ShrinkPredicate<String> {
    ShrinkPredicate { _, candidate in
      candidate.hasSuffix(suffix)
    }
  }
}

// MARK: - Predicate Combinators

extension ShrinkPredicate {
  /// Combines this predicate with another using AND logic.
  ///
  /// - Parameter other: Another predicate to combine with.
  /// - Returns: A new predicate that requires both to pass.
  public func and(_ other: ShrinkPredicate<T>) -> ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      self.isValid(original, candidate) && other.isValid(original, candidate)
    }
  }

  /// Combines this predicate with another using OR logic.
  ///
  /// - Parameter other: Another predicate to combine with.
  /// - Returns: A new predicate that requires either to pass.
  public func or(_ other: ShrinkPredicate<T>) -> ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      self.isValid(original, candidate) || other.isValid(original, candidate)
    }
  }

  /// Negates this predicate.
  ///
  /// - Returns: A new predicate with inverted logic.
  public var not: ShrinkPredicate<T> {
    ShrinkPredicate { original, candidate in
      !self.isValid(original, candidate)
    }
  }
}

// MARK: - Field-Preserving Predicates

/// Creates a shrink predicate that preserves a specific field.
///
/// - Parameters:
///   - keyPath: The key path to the field to preserve.
/// - Returns: A predicate that ensures the field doesn't change.
public func preserveField<T: Sendable, V: Equatable & Sendable>(
  _ keyPath: KeyPath<T, V> & Sendable
) -> ShrinkPredicate<T> {
  ShrinkPredicate { original, candidate in
    original[keyPath: keyPath] == candidate[keyPath: keyPath]
  }
}

/// Creates a shrink predicate that preserves multiple fields.
///
/// - Parameter check: A function that validates field preservation.
/// - Returns: A predicate that ensures the fields don't change.
public func preserveFields<T>(
  _ check: @escaping @Sendable (T, T) -> Bool
) -> ShrinkPredicate<T> where T: Sendable {
  ShrinkPredicate(isValid: check)
}

// MARK: - Shrink Extensions

extension Shrink where T: Sendable {
  /// Filters shrink candidates using a predicate.
  ///
  /// - Parameter predicate: The predicate to filter candidates.
  /// - Returns: A new shrink that only produces valid candidates.
  public func filtered(by predicate: ShrinkPredicate<T>) -> Shrink<T> {
    Shrink { value in
      self.shrink(value).filter { candidate in
        predicate.validate(original: value, candidate: candidate)
      }
    }
  }
}

extension Shrink where T: Hashable {
  /// Filters shrink candidates to remove identical values.
  ///
  /// - Returns: A new Shrink that produces unique candidates only.
  public func uniqueCandidates() -> Shrink<T> {
    Shrink { value in
      var seen = Set<T>()
      return self.shrink(value).filter { candidate in
        guard !seen.contains(candidate) else { return false }
        seen.insert(candidate)
        return true
      }
    }
  }
}
