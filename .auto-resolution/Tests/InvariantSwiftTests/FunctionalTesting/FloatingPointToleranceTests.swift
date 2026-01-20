import Foundation
import Testing

@testable import InvariantSwift
import InvariantSwiftCore

@Suite("Floating Point Tolerance Tests")
struct FloatingPointToleranceTests {

  @Test("Absolute tolerance near zero")
  func absoluteToleranceNearZero() {
    let a = 0.0000001
    let b = 0.0

    #expect(a.isApproximatelyEqual(to: b, tolerance: .absolute(1e-6)))
    #expect(!a.isApproximatelyEqual(to: b, tolerance: .absolute(1e-8)))
  }

  @Test("Absolute tolerance for large values")
  func absoluteToleranceLargeValues() {
    let a = 1_000_000.0
    let b = 1_000_001.0

    #expect(!a.isApproximatelyEqual(to: b, tolerance: .absolute(1e-6)))
    #expect(a.isApproximatelyEqual(to: b, tolerance: .absolute(2.0)))
  }

  @Test("Relative tolerance across different scales")
  func relativeToleranceDifferentScales() {
    let small1 = 0.001
    let small2 = 0.0010001

    #expect(small1.isApproximatelyEqual(to: small2, tolerance: .relative(1e-3)))

    let large1 = 1_000_000.0
    let large2 = 1_000_001.0

    #expect(large1.isApproximatelyEqual(to: large2, tolerance: .relative(1e-5)))
  }

  @Test("Relative tolerance exact match")
  func relativeToleranceExactMatch() {
    let a = 42.0
    let b = 42.0

    #expect(a.isApproximatelyEqual(to: b, tolerance: .relative(0.0)))
  }

  @Test("ULP tolerance for precise comparisons")
  func ulpTolerancePrecise() {
    let a = 1.0
    let b = a.nextUp

    #expect(a.isApproximatelyEqual(to: b, tolerance: .ulp(1)))
    #expect(!a.isApproximatelyEqual(to: b, tolerance: .ulp(0)))
  }

  @Test("ULP tolerance for multiple steps")
  func ulpToleranceMultipleSteps() {
    let a = 1.0
    var b = a
    for _ in 0..<3 {
      b = b.nextUp
    }

    #expect(a.isApproximatelyEqual(to: b, tolerance: .ulp(3)))
    #expect(!a.isApproximatelyEqual(to: b, tolerance: .ulp(2)))
  }

  @Test("NaN handling in approximate equality")
  func nanHandling() {
    let nan1 = Double.nan
    let nan2 = Double.nan

    #expect(nan1.isApproximatelyEqual(to: nan2, tolerance: .absolute(1e-6)))
    #expect(nan1.isApproximatelyEqual(to: nan2, tolerance: .relative(1e-6)))
    #expect(nan1.isApproximatelyEqual(to: nan2, tolerance: .ulp(1)))

    let finite = 42.0
    #expect(!finite.isApproximatelyEqual(to: nan1, tolerance: .absolute(1e6)))
  }

  @Test("Infinity handling in approximate equality")
  func infinityHandling() {
    let inf = Double.infinity
    let negInf = -Double.infinity

    #expect(inf.isApproximatelyEqual(to: inf, tolerance: .absolute(1e-6)))
    #expect(!inf.isApproximatelyEqual(to: negInf, tolerance: .absolute(1e6)))

    let finite = 1e308
    #expect(!inf.isApproximatelyEqual(to: finite, tolerance: .absolute(1e308)))
  }

  @Test("Signed zero handling")
  func signedZeroHandling() {
    let posZero: Double = 0.0
    let negZero: Double = -0.0

    #expect(posZero.isApproximatelyEqual(to: negZero, tolerance: .absolute(0.0)))
    #expect(posZero.isApproximatelyEqual(to: negZero, tolerance: .relative(0.0)))
    #expect(posZero.isApproximatelyEqual(to: negZero, tolerance: .ulp(0)))

    #expect(posZero == negZero, "Signed zeros are equal per IEEE 754")

    #expect((1.0 / posZero).isInfinite && (1.0 / posZero) > 0, "1/+0 = +∞")
    #expect((1.0 / negZero).isInfinite && (1.0 / negZero) < 0, "1/-0 = -∞")
  }

  @Test("Float tolerance helpers")
  func floatToleranceHelpers() {
    let a: Float = 1.0 / 3.0
    let b: Float = 0.333333

    #expect(a.isApproximatelyEqual(to: b, tolerance: .absolute(1e-5)))
    #expect(!a.isApproximatelyEqual(to: b, tolerance: .absolute(1e-7)))
  }

  @Test("Tolerance is symmetric")
  func toleranceSymmetric() {
    let a = 100.0
    let b = 100.01

    let tolerance = FloatingPointTolerance<Double>.absolute(0.02)

    #expect(a.isApproximatelyEqual(to: b, tolerance: tolerance))
    #expect(b.isApproximatelyEqual(to: a, tolerance: tolerance))
  }

  @Test("Tolerance edge case: zero comparison")
  func toleranceZeroComparison() {
    let zero = 0.0
    let tiny = 1e-10

    #expect(zero.isApproximatelyEqual(to: tiny, tolerance: .absolute(1e-9)))
    #expect(!zero.isApproximatelyEqual(to: tiny, tolerance: .absolute(1e-11)))
  }

  @Test("Relative tolerance handles zero denominators")
  func relativeToleranceZeroDenominator() {
    let zero1 = 0.0
    let zero2 = 0.0

    #expect(zero1.isApproximatelyEqual(to: zero2, tolerance: .relative(1e-6)))
  }

  @Test("ULP tolerance with negative numbers")
  func ulpToleranceNegativeNumbers() {
    let a = -1.0
    let b = a.nextDown

    #expect(a.isApproximatelyEqual(to: b, tolerance: .ulp(1)))
    #expect(!a.isApproximatelyEqual(to: b, tolerance: .ulp(0)))
  }

  @Test("ULP tolerance across zero")
  func ulpToleranceAcrossZero() {
    let small = Double.ulpOfOne * 5
    let negSmall = -small

    #expect(small.isApproximatelyEqual(to: negSmall, tolerance: .ulp(10)))
  }
}
