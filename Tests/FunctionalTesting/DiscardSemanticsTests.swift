import Testing
import InvariantCore
import InvariantSwift

/// Tests for discard semantics in property-based testing (Story S010).
///
/// Verifies that:
/// 1. Properties with restrictive assumptions return `.gaveUp` after exceeding maxDiscarded
/// 2. Predicates are never called for values that fail assumptions
/// 3. Discard counts are accurately tracked
@Suite("Discard Semantics Tests")
struct DiscardSemanticsTests {

  // MARK: - gaveUp Behavior Tests

  @Test("Property with always-false assumption returns gaveUp")
  func testAlwaysFalseAssumptionGavesUp() {
    // Arrange: assumption that always fails
    let property = Property(
      generator: Gen<Int>.int,
      assumption: { _ in false },
      predicate: { _ in true }
    )

    let config = PropertyConfig(
      iterations: 100,
      maxDiscarded: 50
    )

    // Act
    let result = runPropertySynchronously(property, config: config)

    // Assert: should give up after maxDiscarded + 1 attempts
    switch result {
    case .gaveUp(let discarded, let iterations):
      #expect(discarded == 51, "Should discard exactly maxDiscarded + 1 times")
      #expect(iterations == 0, "Should have 0 successful iterations")

    case .success:
      Issue.record("Expected .gaveUp but got .success")

    case .failure:
      Issue.record("Expected .gaveUp but got .failure")
    }
  }

  @Test("Property with rarely-passing assumption returns gaveUp")
  func testRestrictiveAssumptionGavesUp() {
    // Arrange: assumption that passes very rarely (1 in 1000000)
    let property = Property(
      generator: Gen<Int>.int(in: 0...999_999),
      assumption: { $0 == 42 },  // Very restrictive
      predicate: { _ in true }
    )

    let config = PropertyConfig(
      iterations: 100,
      maxDiscarded: 200
    )

    // Act
    let result = runPropertySynchronously(property, config: config)

    // Assert: should give up due to too many discards
    switch result {
    case .gaveUp(let discarded, _):
      #expect(discarded > config.maxDiscarded, "Should exceed maxDiscarded")

    case .success:
      Issue.record("Expected .gaveUp but got .success (very unlikely)")

    case .failure:
      Issue.record("Expected .gaveUp but got .failure")
    }
  }

  // MARK: - Predicate Isolation Tests

  @Test("Predicate is never called for discarded values")
  func testPredicateNotCalledForDiscardedValues() {
    // Arrange: track predicate invocations
    var predicateCallCount = 0
    var predicateReceivedValues: [Int] = []

    let property = Property(
      generator: Gen<Int>.int(in: 0...99),
      assumption: { $0 >= 50 },  // Only pass values >= 50
      predicate: { value in
        predicateCallCount += 1
        predicateReceivedValues.append(value)
        return true
      }
    )

    let config = PropertyConfig(iterations: 20, maxDiscarded: 1000)

    // Act
    let result = runPropertySynchronously(property, config: config)

    // Assert
    switch result {
    case .success(let iterations):
      #expect(iterations == 20, "Should complete 20 iterations")
      #expect(predicateCallCount == 20, "Predicate called exactly once per successful iteration")
      #expect(
        predicateReceivedValues.allSatisfy { $0 >= 50 },
        "All values received by predicate should pass assumption"
      )

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")

    case .failure:
      Issue.record("Unexpected .failure")
    }
  }

  // MARK: - Discard Counting Tests

  @Test("Discard count is accurate in gaveUp result")
  func testDiscardCountAccuracy() {
    // Use a custom generator that tracks total generations
    let trackingGen = Gen<Int> { rng, _ in
      let value = Int.random(in: 0..<100, using: &rng)
      return value
    }

    // Assumption passes for ~50% of values
    let property = Property(
      generator: trackingGen,
      assumption: { $0 >= 50 },
      predicate: { _ in true }
    )

    let config = PropertyConfig(
      iterations: 10,
      maxDiscarded: 5  // Low threshold to trigger gaveUp
    )

    // Act
    let result = runPropertySynchronously(property, config: config)

    // Assert: Either succeeds or gives up with accurate count
    switch result {
    case .gaveUp(let discarded, let iterations):
      #expect(discarded == 6, "Discard count should be maxDiscarded + 1 when giving up")
      #expect(iterations < config.iterations, "Should not complete all iterations")

    case .success:
      // Success is possible if we got lucky with assumptions
      break

    case .failure:
      Issue.record("Unexpected .failure")
    }
  }

  // MARK: - Shrinking with Assumptions Tests

  @Test("Shrinking respects assumptions")
  func testShrinkingRespectsAssumptions() {
    // Arrange: Property that fails for values > 10 but only tests positive numbers
    let property = Property(
      generator: Gen<Int>.int(in: 0...99).withShrink { n in
        // Shrink towards 0, but include negative candidates
        guard n > 0 else { return [] }
        return [0, n / 2, n - 1, -1, -n]  // -1 and -n should be rejected
      },
      assumption: { $0 >= 0 },  // Only non-negative
      predicate: { $0 <= 10 }  // Fails for values > 10
    )

    let config = PropertyConfig(
      iterations: 100,
      maxShrinks: 100,
      maxDiscarded: 1000,
      seed: Seed(value: 12345)  // Fixed seed for reproducibility
    )

    // Act
    let result = runPropertySynchronously(property, config: config)

    // Assert
    switch result {
    case .failure(_, _, let shrunk, _, _):
      #expect(shrunk >= 0, "Shrunk value should satisfy assumption (non-negative)")
      #expect(shrunk > 10, "Shrunk value should still fail predicate")
      #expect(shrunk == 11, "Shrunk value should be minimal failing case")

    case .success:
      Issue.record("Expected .failure but got .success")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")
    }
  }

  // MARK: - Edge Cases

  @Test("Property with always-true assumption behaves normally")
  func testAlwaysTrueAssumption() {
    let property = Property(
      generator: Gen<Int>.int(in: 0...99),
      assumption: { _ in true },  // Default behavior
      predicate: { _ in true }
    )

    let config = PropertyConfig(iterations: 100)
    let result = runPropertySynchronously(property, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 100, "Should complete all iterations")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp with always-true assumption")

    case .failure:
      Issue.record("Unexpected .failure")
    }
  }

  @Test("Property without explicit assumption works correctly")
  func testPropertyWithoutExplicitAssumption() {
    // Use the simpler init that doesn't take assumption
    let property = Property(
      generator: Gen<Int>.int(in: 0...99)
    ) { value in
      value >= 0
    }

    let config = PropertyConfig(iterations: 50)
    let result = runPropertySynchronously(property, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 50, "Should complete all iterations")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")

    case .failure:
      Issue.record("Unexpected .failure - all values should be >= 0")
    }
  }

  // MARK: - Throwing Property Tests (S012)

  @Test("Throwing predicate that throws produces threwError reason")
  func testThrowingPredicateError() {
    enum TestError: Error {
      case intentional
    }

    let property = ThrowingProperty(
      generator: Gen<Int>.int(in: 0...100)
    ) { _ in
      throw TestError.intentional
    }

    let config = PropertyConfig(iterations: 10)
    let result = runThrowingPropertySynchronously(property, config: config)

    switch result {
    case .failure(_, let iterations, _, let reason, _):
      #expect(iterations == 1, "Should fail on first iteration")
      if case .threwError(let errorString) = reason {
        #expect(errorString.contains("intentional"), "Error should mention 'intentional'")
      } else {
        Issue.record("Expected .threwError reason but got \(reason)")
      }

    case .success:
      Issue.record("Expected .failure but got .success")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")
    }
  }

  @Test("Throwing predicate that returns false produces predicateFailed reason")
  func testThrowingPredicateReturnsFalse() {
    let property = ThrowingProperty(
      generator: Gen<Int>.int(in: 0...100)
    ) { _ in
      false  // Returns false, doesn't throw
    }

    let config = PropertyConfig(iterations: 10)
    let result = runThrowingPropertySynchronously(property, config: config)

    switch result {
    case .failure(_, _, _, let reason, _):
      #expect(reason == .predicateFailed, "Should have predicateFailed reason")

    case .success:
      Issue.record("Expected .failure but got .success")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")
    }
  }

  @Test("Throwing predicate that succeeds returns success")
  func testThrowingPredicateSucceeds() {
    let property = ThrowingProperty(
      generator: Gen<Int>.int(in: 0...100)
    ) { _ in
      true  // Always succeeds
    }

    let config = PropertyConfig(iterations: 50)
    let result = runThrowingPropertySynchronously(property, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 50, "Should complete all iterations")

    case .failure:
      Issue.record("Unexpected .failure")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")
    }
  }

  @Test("Throwing property with assumption respects discards")
  func testThrowingPropertyWithAssumption() {
    enum TestError: Error { case test }

    var predicateCallCount = 0

    let property = ThrowingProperty(
      generator: Gen<Int>.int(in: 0...100),
      assumption: { $0 >= 50 }  // Only half pass
    ) { _ in
      predicateCallCount += 1
      return true
    }

    let config = PropertyConfig(iterations: 10, maxDiscarded: 100)
    let result = runThrowingPropertySynchronously(property, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 10, "Should complete 10 iterations")
      #expect(predicateCallCount == 10, "Predicate called exactly once per successful iteration")

    case .failure:
      Issue.record("Unexpected .failure")

    case .gaveUp:
      Issue.record("Unexpected .gaveUp")
    }
  }
}
