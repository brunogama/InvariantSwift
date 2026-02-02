import Foundation

/// Controls the complexity of generated values in property-based testing.
///
/// `Size` is a hint to generators about how complex values should be. During property testing,
/// size typically increases with iteration count, allowing generators to explore more complex
/// inputs over time. For example, a string generator might produce longer strings as size increases.
///
/// Key characteristics:
/// - Non-negative integer value (values < 0 are clamped to 0)
/// - Used by generators to control depth of nested structures
/// - Passed through the generation pipeline via the random number generator
/// - Affects shrinking depth: larger sizes may produce more complex shrinking trees
///
/// Size is primarily useful for generators of:
/// - Collections (controls maximum length)
/// - Trees and nested structures (controls depth)
/// - Strings (controls character count)
/// - Custom domain-specific types
///
/// Mathematical foundation: In coverage-guided testing, size is part of the generation
/// context along with seed, enabling controlled exploration of the input space.
///
/// - Parameters:
///   - value: The complexity level. Non-negative integers. Values < 0 are clamped to 0.
///
/// - Example:
///   ```swift
///   let small = Size(value: 10)      // Small arrays/strings
///   let medium = Size(value: 50)     // Medium collections
///   let scaled = medium.scaled(by: 2.0)  // 100 - useful for stress testing
///   ```
///
/// - See Also: ``Gen``, ``Shrink``
public struct Size: Sendable {
  public let value: Int

  /// Initialize Size with explicit complexity level.
  ///
  /// Creates a Size value with the given complexity. Values are automatically
  /// clamped to non-negative integers (any negative value becomes 0).
  ///
  /// - Parameters:
  ///   - value: The complexity level. Negative values are clamped to 0.
  ///
  /// - Example:
  ///   ```swift
  ///   let size = Size(value: 50)
  ///   assert(size.value == 50)
  ///
  ///   let negative = Size(value: -10)
  ///   assert(negative.value == 0)  // Clamped to 0
  ///   ```
  public init(value: Int) {
    self.value = max(0, value)
  }

  /// Scales the size by a multiplicative factor.
  ///
  /// Multiplies the current size value by the given factor, useful for:
  /// - Stress testing: `size.scaled(by: 10.0)` for 10x complexity
  /// - Reduced testing: `size.scaled(by: 0.5)` for quick sanity checks
  /// - Dynamic scaling based on test results
  ///
  /// The result is clamped to non-negative integers (fractional parts are truncated,
  /// negative results become 0).
  ///
  /// - Parameters:
  ///   - factor: Multiplicative factor. Examples: 0.5 (half), 1.0 (unchanged), 2.0 (double)
  ///
  /// - Returns: New `Size` with scaled value, clamped to non-negative range
  ///
  /// - Example:
  ///   ```swift
  ///   let size = Size(value: 50)
  ///   let doubled = size.scaled(by: 2.0)    // Size(value: 100)
  ///   let halved = size.scaled(by: 0.5)     // Size(value: 25)
  ///   let stress = size.scaled(by: 10.0)    // Size(value: 500)
  ///   ```
  public func scaled(by factor: Double) -> Self {
    guard factor.isFinite else { return Self(value: 0) }
    let scaled = Double(value) * factor
    guard scaled.isFinite else { return Self(value: Int.max) }
    return Self(value: max(0, Int(scaled)))
  }

  /// Predefined small size constant for quick tests.
  public static let small = Self(value: 10)
  /// Predefined medium size constant for balanced coverage.
  public static let medium = Self(value: 50)
  /// Predefined large size constant for stress testing.
  public static let large = Self(value: 100)
}
