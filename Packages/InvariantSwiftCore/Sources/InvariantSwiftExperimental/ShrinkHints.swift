import Foundation
import InvariantSwiftCore

/// Common shrink targets for built-in types.
///
/// Specifies the preferred target value when shrinking fails during property testing.
/// Shrinking iteratively simplifies a failing test case to find the minimal counterexample.
/// By providing a hint, you guide the shrinking process toward semantically meaningful values.
///
/// - SeeAlso: `ShrinkHint`, `@ShrinkTowards`
public enum ShrinkTarget<T: Sendable>: Sendable {
  /// Shrink toward a specific value.
  ///
  /// Useful when you know the ideal "simple" value for your domain.
  /// For example, shrinking counts toward 1 instead of 0 when testing positive counts.
  case value(T)

  /// Shrink toward zero (numeric types).
  ///
  /// The default for most numeric generators. Useful for counts, indices, and quantities.
  case zero

  /// Shrink toward empty (collections, strings).
  ///
  /// The default for collections and strings. Finds the minimal input that still triggers failure.
  case empty

  /// Shrink toward identity element (monoids).
  ///
  /// For algebraic types, shrink toward the identity element:
  /// - Addition: 0
  /// - Multiplication: 1
  /// - Concatenation: empty string/array
  case identity

  /// Default shrinking (no preference).
  ///
  /// Uses the generator's built-in shrink strategy without modification.
  case `default`
}

/// Configuration for shrink behavior on a parameter.
///
/// `ShrinkHint` allows you to guide shrinking toward values that make sense in your domain.
/// This produces more meaningful minimal counterexamples.
///
/// Without hints:
/// ```swift
/// // Property: count must be positive
/// // Failure: count = 42 violates property
/// // Shrinks to: count = 0 (unhelpful - violates precondition)
/// ```
///
/// With hints:
/// ```swift
/// @PropertyTest
/// func testPositiveCount(@ShrinkTowards(1) count: Int) -> Bool {
///   count > 0  // Precondition
///   // ... property logic
/// }
/// // Failure: count = 42 violates property
/// // Shrinks to: count = 1 (helpful - smallest valid value)
/// ```
///
/// - SeeAlso: `@ShrinkTowards`, `ShrinkTarget`
public struct ShrinkHint<T: Sendable>: Sendable {
  /// The target to shrink toward.
  public let target: ShrinkTarget<T>

  /// Weight for preferring this target (0.0-1.0).
  ///
  /// Higher weights give more priority to candidates closer to the target.
  /// Default is 1.0 (full preference).
  public let weight: Double

  /// Maximum shrink iterations for this parameter.
  ///
  /// Limits the number of shrink attempts for this specific parameter.
  /// Useful for expensive properties or when you want faster feedback.
  /// `nil` means no parameter-specific limit (uses global config).
  public let maxIterations: Int?

  /// Creates a shrink hint with the given configuration.
  ///
  /// - Parameters:
  ///   - target: The value to shrink toward
  ///   - weight: Preference weight (0.0-1.0), default 1.0
  ///   - maxIterations: Max shrink iterations for this parameter, default nil
  public init(
    target: ShrinkTarget<T>,
    weight: Double = 1.0,
    maxIterations: Int? = nil
  ) {
    self.target = target
    self.weight = min(1.0, max(0.0, weight))  // Clamp to [0.0, 1.0]
    self.maxIterations = maxIterations
  }

  /// Creates a hint to shrink toward a specific value.
  ///
  /// - Parameter value: The target value
  /// - Returns: A shrink hint configured to prefer this value
  ///
  /// - Example:
  ///   ```swift
  ///   let hint = ShrinkHint.towards(10)
  ///   // Shrinks: 100 → 55 → 32 → 21 → 15 → 12 → 11 → 10
  ///   ```
  public static func towards(_ value: T) -> ShrinkHint<T> {
    Self(target: .value(value))
  }

  /// Creates a hint to shrink toward zero (numeric types).
  ///
  /// - Returns: A shrink hint targeting zero
  ///
  /// - Example:
  ///   ```swift
  ///   let hint = ShrinkHint<Int>.towardsZero()
  ///   // Shrinks: 100 → 50 → 25 → 12 → 6 → 3 → 1 → 0
  ///   ```
  public static func towardsZero() -> ShrinkHint<T> where T: Numeric {
    Self(target: .zero)
  }

  /// Creates a hint to shrink toward empty (collection types).
  ///
  /// - Returns: A shrink hint targeting an empty collection
  ///
  /// - Example:
  ///   ```swift
  ///   let hint = ShrinkHint<[Int]>.towardsEmpty()
  ///   // Shrinks: [1,2,3,4] → [1,2] → [1] → []
  ///   ```
  public static func towardsEmpty() -> ShrinkHint<T> where T: Collection {
    Self(target: .empty)
  }
}

// MARK: - Shrink Extensions for Targeted Shrinking

extension Shrink where T: Comparable {
  /// Creates a shrink strategy that prefers values closer to target.
  ///
  /// The shrink tree prioritizes candidates that are "closer" to the target,
  /// where closeness is defined by distance for comparable types.
  ///
  /// This function provides a basic implementation that always includes the target value.
  /// For more sophisticated shrinking with intermediate steps, use type-specific overloads.
  ///
  /// Shrinking behavior:
  /// - Returns target as the primary shrink candidate
  /// - Suitable for all Comparable types
  ///
  /// - Parameters:
  ///   - target: The value to shrink toward
  ///   - value: The current value to shrink
  ///
  /// - Returns: Array containing the target value (if different from input)
  ///
  /// - Example:
  ///   ```swift
  ///   let shrink = Shrink<Int>.towards(10, from: 100)
  ///   // Returns: [10]
  ///   ```
  public static func towards(_ target: T, from value: T) -> [T] {
    value == target ? [] : [target]
  }
}

extension Shrink where T: BinaryInteger & Comparable {
  /// Creates a shrink strategy for integers that uses binary shrinking toward target.
  ///
  /// Generates intermediate values between current and target using binary search pattern,
  /// producing a more gradual path to the minimal counterexample.
  ///
  /// - Parameters:
  ///   - target: The integer to shrink toward
  ///   - value: The current integer value
  ///
  /// - Returns: Array of shrink candidates, ordered by preference
  ///
  /// - Example:
  ///   ```swift
  ///   let shrink = Shrink<Int>.towardsInt(10, from: 100)
  ///   // Returns: [10, 55, 77, 88, 94, 97, 98, 99]
  ///   ```
  public static func towardsInt(_ target: T, from value: T) -> [T] {
    guard value != target else { return [] }

    var candidates: [T] = [target]
    candidates.append(contentsOf: binaryShrinkSteps(from: value, to: target))
    candidates.append(contentsOf: boundarySteps(from: value, to: target))

    return removeDuplicates(from: candidates)
  }

  // MARK: - Private Helpers

  private static func binaryShrinkSteps(from value: T, to target: T) -> [T] {
    let distance = value > target ? value - target : target - value
    var step = distance / 2
    var steps: [T] = []

    while step > 0 {
      let intermediate = value > target ? target + step : value + step
      if intermediate != target && intermediate != value {
        steps.append(intermediate)
      }
      step /= 2
    }

    return steps
  }

  private static func boundarySteps(from value: T, to target: T) -> [T] {
    if value > target {
      let oneStepBack = target + 1
      return oneStepBack != target && oneStepBack != value ? [oneStepBack] : []
    } else if value < target {
      let oneStepBack = target - 1
      return oneStepBack != target && oneStepBack != value ? [oneStepBack] : []
    }
    return []
  }

  private static func removeDuplicates(from candidates: [T]) -> [T] {
    var seen = Set<String>()
    return candidates.filter { candidate in
      let key = "\(candidate)"
      guard !seen.contains(key) else { return false }
      seen.insert(key)
      return true
    }
  }
}
