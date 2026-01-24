import Testing

@testable import InvariantSwiftCore

/// Tests for ShrinkHint infrastructure and Shrink.towards functionality.
@Suite("ShrinkHint Tests")
struct ShrinkHintsTests {

  // MARK: - ShrinkTarget Tests

  @Test("ShrinkTarget.value creates correct target")
  func testShrinkTargetValue() {
    let target: ShrinkTarget<Int> = .value(10)

    switch target {
    case .value(let value):
      #expect(value == 10)

    default:
      Issue.record("Expected .value case")
    }
  }

  @Test("ShrinkTarget.zero represents zero target")
  func testShrinkTargetZero() {
    let target: ShrinkTarget<Int> = .zero

    switch target {
    case .zero:
      break  // Success
    default:
      Issue.record("Expected .zero case")
    }
  }

  @Test("ShrinkTarget.empty represents empty target")
  func testShrinkTargetEmpty() {
    let target: ShrinkTarget<[Int]> = .empty

    switch target {
    case .empty:
      break  // Success
    default:
      Issue.record("Expected .empty case")
    }
  }

  // MARK: - ShrinkHint Tests

  @Test("ShrinkHint.towards creates correct hint")
  func testShrinkHintTowards() {
    let hint = ShrinkHint<Int>.towards(10)

    #expect(hint.weight == 1.0)
    #expect(hint.maxIterations == nil)

    switch hint.target {
    case .value(let value):
      #expect(value == 10)

    default:
      Issue.record("Expected .value target")
    }
  }

  @Test("ShrinkHint.towardsZero creates zero target hint")
  func testShrinkHintTowardsZero() {
    let hint = ShrinkHint<Int>.towardsZero()

    switch hint.target {
    case .zero:
      break  // Success
    default:
      Issue.record("Expected .zero target")
    }
  }

  @Test("ShrinkHint.towardsEmpty creates empty target hint")
  func testShrinkHintTowardsEmpty() {
    let hint = ShrinkHint<[Int]>.towardsEmpty()

    switch hint.target {
    case .empty:
      break  // Success
    default:
      Issue.record("Expected .empty target")
    }
  }

  @Test("ShrinkHint with custom weight")
  func testShrinkHintCustomWeight() {
    let hint = ShrinkHint(target: ShrinkTarget<Int>.value(5), weight: 0.5)

    #expect(hint.weight == 0.5)
  }

  @Test("ShrinkHint weight clamped to [0, 1]")
  func testShrinkHintWeightClamping() {
    let tooHigh = ShrinkHint(target: ShrinkTarget<Int>.value(1), weight: 1.5)
    let tooLow = ShrinkHint(target: ShrinkTarget<Int>.value(1), weight: -0.5)

    #expect(tooHigh.weight == 1.0)
    #expect(tooLow.weight == 0.0)
  }

  @Test("ShrinkHint with max iterations")
  func testShrinkHintMaxIterations() {
    let hint = ShrinkHint(target: ShrinkTarget<Int>.value(10), maxIterations: 50)

    #expect(hint.maxIterations == 50)
  }

  // MARK: - Shrink.towards Tests

  @Test("Shrink.towards same value returns empty")
  func testShrinkTowardsSameValue() {
    let candidates = Shrink<Int>.towards(10, from: 10)

    #expect(candidates.isEmpty)
  }

  @Test("Shrink.towards different value returns target")
  func testShrinkTowardsDifferentValue() {
    let candidates = Shrink<Int>.towards(10, from: 100)

    #expect(!candidates.isEmpty)
    #expect(candidates[0] == 10)
  }

  @Test("Shrink.towards works with strings")
  func testShrinkTowardsString() {
    let candidates = Shrink<String>.towards("test", from: "production")

    #expect(!candidates.isEmpty)
    #expect(candidates[0] == "test")
  }

  // MARK: - Shrink.towardsInt Tests

  @Test("Shrink.towardsInt same value returns empty")
  func testShrinkTowardsIntSameValue() {
    let candidates = Shrink<Int>.towardsInt(10, from: 10)

    #expect(candidates.isEmpty)
  }

  @Test("Shrink.towardsInt includes target")
  func testShrinkTowardsIntIncludesTarget() {
    let candidates = Shrink<Int>.towardsInt(10, from: 100)

    #expect(candidates.contains(10))
    #expect(candidates[0] == 10)  // Target is first
  }

  @Test("Shrink.towardsInt includes intermediate values")
  func testShrinkTowardsIntIntermediates() {
    let candidates = Shrink<Int>.towardsInt(10, from: 100)

    // Should include values between 10 and 100
    #expect(candidates.count > 1)

    // All values should be between target and original
    for candidate in candidates {
      #expect(candidate >= 10)
      #expect(candidate <= 100)
    }
  }

  @Test("Shrink.towardsInt binary shrinking pattern")
  func testShrinkTowardsIntBinaryPattern() {
    let candidates = Shrink<Int>.towardsInt(0, from: 100)

    // First candidate should be target (0)
    #expect(candidates[0] == 0)

    // Should include binary shrinking steps: 50, 25, 12, etc.
    #expect(candidates.contains(50))
  }

  @Test("Shrink.towardsInt no duplicates")
  func testShrinkTowardsIntNoDuplicates() {
    let candidates = Shrink<Int>.towardsInt(10, from: 100)

    let uniqueSet = Set(candidates.map { "\($0)" })
    #expect(uniqueSet.count == candidates.count)
  }

  @Test("Shrink.towardsInt shrinking upward")
  func testShrinkTowardsIntUpward() {
    let candidates = Shrink<Int>.towardsInt(100, from: 10)

    // Should include target
    #expect(candidates.contains(100))

    // All values should be between original and target
    for candidate in candidates {
      #expect(candidate >= 10)
      #expect(candidate <= 100)
    }
  }

  @Test("Shrink.towardsInt boundary cases")
  func testShrinkTowardsIntBoundary() {
    let candidates = Shrink<Int>.towardsInt(10, from: 100)

    // Should include values near target (boundary exploration)
    #expect(candidates.contains(11))  // target + 1
  }

  @Test("Shrink.towardsInt with negative numbers")
  func testShrinkTowardsIntNegative() {
    let candidates = Shrink<Int>.towardsInt(-10, from: -100)

    #expect(candidates[0] == -10)  // Target first

    // All values between -100 and -10
    for candidate in candidates {
      #expect(candidate >= -100)
      #expect(candidate <= -10)
    }
  }

  @Test("Shrink.towardsInt from negative to positive")
  func testShrinkTowardsIntCrossingZero() {
    let candidates = Shrink<Int>.towardsInt(10, from: -10)

    #expect(candidates[0] == 10)  // Target first

    // Values should bridge from -10 to 10
    for candidate in candidates {
      #expect(candidate >= -10)
      #expect(candidate <= 10)
    }
  }

  @Test("Shrink.towardsInt small distance")
  func testShrinkTowardsIntSmallDistance() {
    let candidates = Shrink<Int>.towardsInt(10, from: 12)

    #expect(candidates.contains(10))  // Target
    #expect(candidates.contains(11))  // Boundary (10 + 1)

    // Small distance means fewer intermediates
    #expect(candidates.count <= 3)
  }
}
