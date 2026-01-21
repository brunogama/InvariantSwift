import Foundation

// MARK: - Floating Point Generation Mode

/// Mode controlling special value generation for floating-point generators.
///
/// Controls whether generators produce special IEEE 754 values (NaN, infinity).
/// The default mode (`finiteOnly`) ensures deterministic, well-behaved test cases
/// by excluding problematic special values.
///
/// **Default Behavior (GEN-FLOAT-001):**
/// - Default generators produce finite values only
/// - NaN and infinity are excluded by default
/// - This ensures predictable behavior across platforms
///
/// **Special Value Handling:**
/// - `finiteOnly`: No NaN, no infinity (default, safest)
/// - `allowInfinity`: Finite values + ±infinity (no NaN)
/// - `allowNaN`: All IEEE 754 values (finite, infinity, NaN)
///
/// **Cross-Platform Determinism:**
/// - Same seed/size produces same sequence on all platforms
/// - Floating-point operations use stable algorithms
/// - Special value semantics follow IEEE 754 exactly
///
/// - Example:
///   ```swift
///   // Default: finite only
///   let gen1 = Gen<Double>.double
///
///   // Allow infinity
///   let gen2 = Gen<Double>.double(mode: .allowInfinity)
///
///   // Allow all special values
///   let gen3 = Gen<Double>.double(mode: .allowNaN)
///   ```
///
/// - See Also: ``Gen/double``, ``Gen/float``, ``FloatingPointTolerance``
public enum FloatingPointMode: Sendable, Hashable {
  /// Generate finite values only (default).
  ///
  /// Produces normal and subnormal floating-point values, excluding:
  /// - Positive infinity
  /// - Negative infinity
  /// - NaN (not-a-number)
  ///
  /// This is the safest mode for most property tests, ensuring:
  /// - Arithmetic operations don't produce NaN
  /// - Comparisons work as expected
  /// - Cross-platform determinism
  ///
  /// - Note: This is the default mode per GEN-FLOAT-001 requirement.
  case finiteOnly

  /// Generate finite values and infinity, but not NaN.
  ///
  /// Produces normal, subnormal, and infinite values, excluding:
  /// - NaN (not-a-number)
  ///
  /// Use when testing overflow/underflow behavior but avoiding
  /// NaN's unusual comparison semantics (NaN != NaN).
  case allowInfinity

  /// Generate all IEEE 754 values including NaN.
  ///
  /// Produces all possible floating-point values:
  /// - Normal values
  /// - Subnormal values
  /// - Positive and negative infinity
  /// - NaN (not-a-number)
  ///
  /// Use with caution: NaN comparisons behave unusually:
  /// - `NaN != NaN` (breaks reflexivity)
  /// - `!(NaN < x) && !(NaN > x) && !(NaN == x)` for any x
  ///
  /// - Warning: Properties using `allowNaN` must handle NaN explicitly.
  ///   Use `isNaN` checks instead of equality comparisons.
  case allowNaN
}

// MARK: - Floating Point Tolerance

/// Tolerance specification for approximate floating-point comparisons.
///
/// Floating-point arithmetic is inherently imprecise due to limited precision.
/// This type provides standard tolerance strategies for comparing floating-point
/// values in property tests.
///
/// **Why Tolerance Matters:**
/// - Floating-point arithmetic accumulates rounding errors
/// - Different operation orders may yield slightly different results
/// - Cross-platform differences in FPU implementations
/// - Avoid false failures from insignificant precision differences
///
/// **Choosing a Tolerance:**
/// - `.absolute(epsilon)`: For values near zero or when scale is known
/// - `.relative(factor)`: For values across different scales
/// - `.ulp(distance)`: For precise floating-point algorithm testing
///
/// **Caveat - Signed Zero:**
/// - IEEE 754 defines +0.0 and -0.0 as distinct but equal
/// - `+0.0 == -0.0` is true, but `1.0 / +0.0 != 1.0 / -0.0`
/// - Tolerance comparisons treat them as equal
///
/// **Caveat - NaN Comparisons:**
/// - NaN != NaN per IEEE 754 (breaks reflexivity)
/// - Tolerance comparisons consider all NaNs equivalent
/// - Use `isNaN` for explicit NaN detection
///
/// - Example:
///   ```swift
///   // Absolute tolerance (good for values near zero)
///   #expect(value1.isApproximatelyEqual(to: value2, tolerance: .absolute(1e-10)))
///
///   // Relative tolerance (good for varying scales)
///   #expect(large1.isApproximatelyEqual(to: large2, tolerance: .relative(1e-6)))
///
///   // ULP tolerance (precise algorithm testing)
///   #expect(result.isApproximatelyEqual(to: expected, tolerance: .ulp(2)))
///   ```
///
/// - See Also: ``BinaryFloatingPoint/isApproximatelyEqual(to:tolerance:)``
public enum FloatingPointTolerance<T: BinaryFloatingPoint>: Sendable, Hashable {
  /// Absolute tolerance: |a - b| <= epsilon.
  ///
  /// Use when comparing values near zero or when the scale is known.
  ///
  /// - Parameters:
  ///   - epsilon: Maximum allowed absolute difference
  ///
  /// - Example:
  ///   ```swift
  ///   // Good for small values
  ///   0.0000001.isApproximatelyEqual(to: 0.0, tolerance: .absolute(1e-6))  // true
  ///
  ///   // Less effective for large values
  ///   1_000_000.0.isApproximatelyEqual(to: 1_000_001.0, tolerance: .absolute(1e-6))  // false
  ///   ```
  case absolute(T)

  /// Relative tolerance: |a - b| / max(|a|, |b|) <= factor.
  ///
  /// Use when comparing values across different scales.
  ///
  /// - Parameters:
  ///   - factor: Maximum allowed relative difference (typically 1e-6 to 1e-12)
  ///
  /// - Example:
  ///   ```swift
  ///   // Good for values at different scales
  ///   1_000_000.0.isApproximatelyEqual(to: 1_000_001.0, tolerance: .relative(1e-5))  // true
  ///   0.001.isApproximatelyEqual(to: 0.0010001, tolerance: .relative(1e-5))  // true
  ///   ```
  case relative(T)

  /// ULP tolerance: values differ by at most N units in the last place.
  ///
  /// Use for precise floating-point algorithm testing. ULP (Unit in the Last Place)
  /// measures discrete representational distance between floating-point values.
  ///
  /// - Parameters:
  ///   - distance: Maximum ULP distance (typically 1-4 for robust algorithms)
  ///
  /// - Example:
  ///   ```swift
  ///   // Precise algorithm comparison
  ///   result.isApproximatelyEqual(to: expected, tolerance: .ulp(2))
  ///   ```
  ///
  /// - Note: ULP distance is scale-aware and accounts for floating-point representation.
  case ulp(Int)
}

// MARK: - Approximate Equality Extension

extension BinaryFloatingPoint {
  /// Check if two floating-point values are approximately equal within a tolerance.
  ///
  /// Performs tolerance-aware comparison suitable for property testing.
  /// Handles special cases (NaN, infinity, signed zero) correctly.
  ///
  /// **Special Value Handling:**
  /// - NaN: All NaN values are considered approximately equal to each other
  /// - Infinity: Only exact infinity matches (±∞ == ±∞)
  /// - Signed Zero: +0.0 and -0.0 are considered approximately equal
  ///
  /// **Tolerance Types:**
  /// - `.absolute(eps)`: |self - other| <= eps
  /// - `.relative(factor)`: |self - other| / max(|self|, |other|) <= factor
  /// - `.ulp(n)`: ULP distance <= n
  ///
  /// - Parameters:
  ///   - other: Value to compare against
  ///   - tolerance: Tolerance specification
  ///
  /// - Returns: `true` if values are approximately equal within tolerance
  ///
  /// - Example:
  ///   ```swift
  ///   let a = 1.0 / 3.0
  ///   let b = 0.333333
  ///   #expect(a.isApproximatelyEqual(to: b, tolerance: .absolute(1e-5)))
  ///   ```
  public func isApproximatelyEqual(
    to other: Self,
    tolerance: FloatingPointTolerance<Self>
  ) -> Bool {
    if handleSpecialValues(other) { return true }

    switch tolerance {
    case .absolute(let epsilon):
      return checkAbsoluteTolerance(other, epsilon: epsilon)

    case .relative(let factor):
      return checkRelativeTolerance(other, factor: factor)

    case .ulp(let distance):
      return checkULPTolerance(other, distance: distance)
    }
  }

  private func handleSpecialValues(_ other: Self) -> Bool {
    if self.isNaN && other.isNaN { return true }
    if self.isInfinite || other.isInfinite { return self == other }
    if self == 0 && other == 0 { return true }
    return false
  }

  private func checkAbsoluteTolerance(_ other: Self, epsilon: Self) -> Bool {
    abs(self - other) <= epsilon
  }

  private func checkRelativeTolerance(_ other: Self, factor: Self) -> Bool {
    let maxMagnitude = max(abs(self), abs(other))
    guard maxMagnitude > 0 else { return true }
    return abs(self - other) / maxMagnitude <= factor
  }

  private func checkULPTolerance(_ other: Self, distance: Int) -> Bool {
    guard self.sign == other.sign else {
      return abs(self) <= Self.ulpOfOne * Self(distance)
        && abs(other) <= Self.ulpOfOne * Self(distance)
    }

    return countULPSteps(to: other, maxSteps: distance)
  }

  private func countULPSteps(to target: Self, maxSteps: Int) -> Bool {
    var current = self
    for _ in 0..<maxSteps {
      if current == target { return true }
      current = current.sign == .plus ? current.nextUp : current.nextDown
      if current == target { return true }
    }

    current = self
    for _ in 0..<maxSteps {
      current = current.sign == .plus ? current.nextDown : current.nextUp
      if current == target { return true }
    }

    return false
  }
}
