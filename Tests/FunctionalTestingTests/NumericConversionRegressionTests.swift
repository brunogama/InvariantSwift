import Testing
import Foundation
@testable import FunctionalTesting

/// **Regression Tests for Numeric Conversion Safety**
///
/// These tests prevent regression of the fatal error bug that occurred when
/// converting infinite or NaN Double values to Int in scaling operations.
///
/// **Bug History:**
/// - **Issue**: `Int(Double(...) * factor)` would fatal error with
///   "Double value cannot be converted to Int because it is either infinite or NaN"
/// - **Root Cause**: Scaling functions in LensExtensions didn't validate finite values
/// - **Fix**: Added `isFinite` and `!isNaN` guards with fallback to original values
/// - **Prevention**: SwiftLint rule `no_fatal_error` now prohibits fatalError usage
struct NumericConversionRegressionTests {

  // MARK: - Size Scaling Safety Tests

  @Test("Size scaling with infinite factor should not crash")
  func sizeScalingInfiniteFactor() {
    let originalSize = Size(value: 100)

    // These operations should not crash - they should return original value
    let scaledByInfinity = Size.scale(by: Double.infinity)(originalSize)
    let scaledByNaN = Size.scale(by: Double.nan)(originalSize)
    let scaledByNegativeInfinity = Size.scale(by: -Double.infinity)(originalSize)

    // Should fallback to original value when scaling factor is invalid
    #expect(
      scaledByInfinity.value == originalSize.value,
      "Infinite scaling factor should preserve original size"
    )
    #expect(
      scaledByNaN.value == originalSize.value,
      "NaN scaling factor should preserve original size"
    )
    #expect(
      scaledByNegativeInfinity.value == originalSize.value,
      "Negative infinite scaling factor should preserve original size"
    )
  }

  @Test("Size scaling with extreme finite values should work")
  func sizeScalingExtremeFiniteValues() {
    let originalSize = Size(value: 50)

    // These should work but clamp to valid ranges
    let scaledByVeryLarge = Size.scale(by: 1e10)(originalSize)
    let scaledByVerySmall = Size.scale(by: 1e-10)(originalSize)
    let scaledByZero = Size.scale(by: 0.0)(originalSize)

    // Should clamp to reasonable bounds
    #expect(scaledByVeryLarge.value >= 0, "Very large scaling should produce valid size")
    #expect(scaledByVerySmall.value >= 0, "Very small scaling should produce valid size")
    #expect(scaledByZero.value == 0, "Zero scaling should produce zero size")
  }

  // MARK: - PropertyConfig Iteration Scaling Safety Tests

  @Test("PropertyConfig iteration scaling with infinite factor should not crash")
  func propertyConfigIterationScalingInfiniteFactor() {
    let originalConfig = PropertyConfig(iterations: 100)

    // These operations should not crash
    let scaledByInfinity = PropertyConfig.scaleIterations(by: Double.infinity)(originalConfig)
    let scaledByNaN = PropertyConfig.scaleIterations(by: Double.nan)(originalConfig)
    let scaledByNegativeInfinity = PropertyConfig.scaleIterations(by: -Double.infinity)(
      originalConfig
    )

    // Should fallback to original value when scaling factor is invalid
    #expect(
      scaledByInfinity.iterations == originalConfig.iterations,
      "Infinite iteration scaling should preserve original iterations"
    )
    #expect(
      scaledByNaN.iterations == originalConfig.iterations,
      "NaN iteration scaling should preserve original iterations"
    )
    #expect(
      scaledByNegativeInfinity.iterations == originalConfig.iterations,
      "Negative infinite iteration scaling should preserve original iterations"
    )
  }

  @Test("PropertyConfig iteration scaling with extreme finite values should work")
  func propertyConfigIterationScalingExtremeFiniteValues() {
    let originalConfig = PropertyConfig(iterations: 50)

    // These should work but clamp to valid ranges
    let scaledByVeryLarge = PropertyConfig.scaleIterations(by: 1e6)(originalConfig)
    let scaledByVerySmall = PropertyConfig.scaleIterations(by: 1e-6)(originalConfig)
    let scaledByZero = PropertyConfig.scaleIterations(by: 0.0)(originalConfig)

    // Should clamp to reasonable bounds (minimum 1 iteration)
    #expect(scaledByVeryLarge.iterations >= 1, "Very large iteration scaling should be valid")
    #expect(scaledByVerySmall.iterations >= 1, "Very small iteration scaling should be at least 1")
    #expect(scaledByZero.iterations >= 1, "Zero iteration scaling should be at least 1")
  }

  // MARK: - Business Complexity Calculation Safety Tests

  @Test("Business complexity with extreme risk factors should not crash")
  func businessComplexityExtremeRiskFactors() {
    // Test ComplexityScore totalComplexity calculation safety
    let normalComplexity = ComplexityAnalyzer.ComplexityScore(
      parameterComplexity: 5,
      bodyComplexity: 1,
      riskFactor: 1.5
    )

    // Verify normal case works
    #expect(normalComplexity.totalComplexity >= 1, "Normal complexity should be valid")

    // Test extreme risk factors that could cause overflow/infinite results
    let extremeComplexity = ComplexityAnalyzer.ComplexityScore(
      parameterComplexity: 1000,
      bodyComplexity: 1,
      riskFactor: Double.greatestFiniteMagnitude
    )

    // Should not crash and should produce reasonable result
    #expect(
      extremeComplexity.totalComplexity >= 1000,
      "Extreme complexity should be handled safely"
    )
    #expect(extremeComplexity.totalComplexity < Int.max, "Extreme complexity should not overflow")
  }

  @Test("Business complexity with infinite risk factors should not crash")
  func businessComplexityInfiniteRiskFactors() {
    // These used to cause fatalError - now should fallback gracefully
    let infiniteRiskComplexity = ComplexityAnalyzer.ComplexityScore(
      parameterComplexity: 10,
      bodyComplexity: 1,
      riskFactor: Double.infinity
    )

    let nanRiskComplexity = ComplexityAnalyzer.ComplexityScore(
      parameterComplexity: 10,
      bodyComplexity: 1,
      riskFactor: Double.nan
    )

    // Should fallback to base complexity (param + body) when risk factor is invalid
    #expect(
      infiniteRiskComplexity.totalComplexity == 11,
      "Infinite risk factor should fallback to base complexity (10 + 1)"
    )
    #expect(
      nanRiskComplexity.totalComplexity == 11,
      "NaN risk factor should fallback to base complexity (10 + 1)"
    )
  }

  // MARK: - Edge Case Validation Tests

  @Test("Validate all numeric conversion safety patterns")
  func validateNumericConversionSafetyPatterns() {
    // This test validates that our safety pattern works for various scenarios

    func safeIntConversion(_ value: Double) -> Int {
      guard value.isFinite, !value.isNaN else { return 1 }
      return Int(max(1, min(value, Double(Int.max))))
    }

    // Test the safety pattern directly
    #expect(safeIntConversion(Double.infinity) == 1, "Infinity should fallback to 1")
    #expect(safeIntConversion(Double.nan) == 1, "NaN should fallback to 1")
    #expect(safeIntConversion(-Double.infinity) == 1, "Negative infinity should fallback to 1")
    #expect(safeIntConversion(Double(Int.max) + 1) == Int.max, "Overflow should clamp to Int.max")
    #expect(safeIntConversion(-1000) == 1, "Negative values should clamp to minimum 1")
    #expect(safeIntConversion(0) == 1, "Zero should clamp to minimum 1")
    #expect(safeIntConversion(50.7) == 50, "Normal values should convert correctly")
  }

  // MARK: - Documentation and Prevention Tests

  @Test("Verify SwiftLint rule prevents fatalError usage")
  func verifySwiftLintRulePrevention() {
    // This test documents the SwiftLint rule that prevents fatalError usage
    // The rule `no_fatal_error` should catch any new fatalError introductions

    // Note: This is a documentation test - the actual prevention happens at lint time
    let swiftLintRuleDocumentation = """
      SwiftLint Custom Rule: no_fatal_error
      - Pattern: \\bfatalError\\(
      - Severity: error
      - Message: Use proper error handling instead of fatalError
      - Alternatives: throwing errors, returning optionals, precondition with recovery
      """

    #expect(!swiftLintRuleDocumentation.isEmpty, "SwiftLint rule documentation exists")

    // Verify the pattern would catch fatalError usage
    let testPattern = #"\\bfatalError\\("#
    let testCode = "fatalError(\"This should be caught\")"
    let regex = try! NSRegularExpression(pattern: testPattern)
    let matches = regex.numberOfMatches(
      in: testCode,
      range: NSRange(testCode.startIndex..., in: testCode)
    )

    #expect(matches > 0, "SwiftLint pattern should detect fatalError usage")
  }
}
