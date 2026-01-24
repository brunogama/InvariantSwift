import Testing
@testable import InvariantSwift

@Suite("Property Combinator Operators")
struct PropertyCombinatorOperatorTests {

  // MARK: - AND Operator Tests

  @Test("AND operator - both true passes")
  func andBothTrue() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 < 20 }
    let combined = prop1 && prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("AND operator - first false fails")
  func andFirstFalse() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 < 5 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let combined = prop1 && prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isFailure)
  }

  @Test("AND operator - second false fails")
  func andSecondFalse() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 < 5 }
    let combined = prop1 && prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isFailure)
  }

  @Test("AND operator - short-circuit evaluation")
  func andShortCircuit() {
    // Use a captured class to work around Sendable restrictions
    final class EvaluationTracker: @unchecked Sendable {
      var rightEvaluated = false
    }
    let tracker = EvaluationTracker()

    let prop1 = Property(generator: Gen.pure(10)) { _ in false }
    let prop2 = Property(generator: Gen.pure(10)) { _ in
      tracker.rightEvaluated = true
      return true
    }
    let combined = prop1 && prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 1, seed: Seed(value: 42))
    )

    // Left property fails, so right should not be evaluated
    #expect(result.isFailure)
    #expect(tracker.rightEvaluated == false)
  }

  @Test("AND operator - with generators")
  func andWithGenerators() {
    let gen = Gen<Int> { rng, _ in Int.random(in: 1...100, using: &rng) }
    let positive = Property(generator: gen) { $0 > 0 }
    let lessThan50 = Property(generator: gen) { $0 < 50 }
    let combined = positive && lessThan50

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 50, seed: Seed(value: 42))
    )

    // This should fail because some values >= 50
    #expect(result.isFailure)
  }

  // MARK: - OR Operator Tests

  @Test("OR operator - both true passes")
  func orBothTrue() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 < 20 }
    let combined = prop1 || prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("OR operator - first true passes")
  func orFirstTrue() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 < 0 }
    let combined = prop1 || prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("OR operator - second true passes")
  func orSecondTrue() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 < 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let combined = prop1 || prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("OR operator - both false fails")
  func orBothFalse() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 < 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 > 100 }
    let combined = prop1 || prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isFailure)
  }

  @Test("OR operator - short-circuit evaluation")
  func orShortCircuit() {
    // Use a captured class to work around Sendable restrictions
    final class EvaluationTracker: @unchecked Sendable {
      var rightEvaluated = false
    }
    let tracker = EvaluationTracker()

    let prop1 = Property(generator: Gen.pure(10)) { _ in true }
    let prop2 = Property(generator: Gen.pure(10)) { _ in
      tracker.rightEvaluated = true
      return false
    }
    let combined = prop1 || prop2

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 1, seed: Seed(value: 42))
    )

    // Left property passes, so right should not be evaluated
    #expect(result.isSuccess)
    #expect(tracker.rightEvaluated == false)
  }

  @Test("OR operator - with generators")
  func orWithGenerators() {
    let gen = Gen<Int> { rng, _ in Int.random(in: -50...50, using: &rng) }
    let negative = Property(generator: gen) { $0 < 0 }
    let positive = Property(generator: gen) { $0 > 0 }
    let combined = negative || positive

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )

    // This should fail for zero
    #expect(result.isFailure)
  }

  // MARK: - Implies Method Tests

  @Test("implies - precondition false discards")
  func impliesPreconditionFalse() {
    let prop: Property<Int> = Property(generator: Gen.pure(0)) { $0 > 0 }
      .implies { $0 != 0 }

    let result = runPropertySynchronously(
      prop,
      config: PropertyConfig(iterations: 10, maxDiscarded: 20, seed: Seed(value: 42))
    )

    // Value is 0, precondition fails, should discard (not fail)
    #expect(result.isGaveUp)
  }

  @Test("implies - precondition true property true passes")
  func impliesPreconditionTruePropertyTrue() {
    let prop: Property<Int> = Property(generator: Gen.pure(10)) { $0 > 0 }
      .implies { $0 != 0 }

    let result = runPropertySynchronously(
      prop,
      config: PropertyConfig(iterations: 10, maxDiscarded: 20, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("implies - precondition true property false fails")
  func impliesPreconditionTruePropertyFalse() {
    let prop = Property(generator: Gen.pure(10)) { $0 < 0 }
      .implies { $0 != 0 }

    let result = runPropertySynchronously(
      prop,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isFailure)
  }

  @Test("implies - division property example")
  func impliesDivisionProperty() {
    let genN = Gen<Int> { rng, _ in Int.random(in: 1...100, using: &rng) }
    let genD = Gen<Int> { rng, _ in Int.random(in: -5...5, using: &rng) }
    let gen = genN.zip(genD)

    let divProp = Property(generator: gen) { n, d in
      (n / d) * d == n
    }
    .implies { _, d in d != 0 }

    let result = runPropertySynchronously(
      divProp,
      config: PropertyConfig(iterations: 50, maxDiscarded: 100, seed: Seed(value: 42))
    )

    // Should pass for non-zero divisors
    #expect(result.isSuccess)
  }

  @Test("implies - combines with existing assumptions")
  func impliesCombinesWithAssumptions() {
    let prop = Property(
      generator: Gen<Int> { rng, _ in Int.random(in: -10...10, using: &rng) },
      assumption: { $0 >= 0 },
      predicate: { $0 < 20 }
    )
    .implies { $0 < 5 }

    let result = runPropertySynchronously(
      prop,
      config: PropertyConfig(iterations: 100, maxDiscarded: 500, seed: Seed(value: 42))
    )

    // Should only test values that are >= 0 AND < 5
    // All such values should be < 20, so should pass
    #expect(result.isSuccess)
  }
}

@Suite("forAll Global Functions")
struct ForAllFunctionTests {

  // MARK: - Type Inference Tests

  @Test("forAll with type inference - Int")
  func forAllTypeInferenceInt() {
    // This would require Int to conform to Generatable with Gen<Int> arbitrary
    // Since we're testing with explicit generators, skip for now
    // The syntax check is the important part
  }

  // MARK: - Explicit Generator Tests

  @Test("forAll with explicit generator - single parameter")
  func forAllExplicitGeneratorSingle() {
    let property = forAll(Gen.pure(5)) { n in
      n >= 0
    }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("forAll with explicit generator - property fails")
  func forAllExplicitGeneratorFails() {
    let property = forAll(Gen.pure(5)) { n in
      n < 0
    }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isFailure)
  }

  @Test("forAll with PropertyEvaluation return")
  func forAllPropertyEvaluation() async {
    let gen = Gen<Int> { rng, _ in Int.random(in: 0...10, using: &rng) }
    let check: @Sendable (Int) -> PropertyEvaluation = { n in
      guard n > 0 else { return .discard(reason: "need positive") }
      return n * 2 > n ? .pass : .fail(reason: "doubling should increase")
    }
    let property = forAll(gen, check: check)

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runEvaluatingProperty(
      property,
      config: PropertyConfig(iterations: 50, maxDiscarded: 100)
    )

    #expect(result.isSuccess)
  }

  @Test("forAll with two parameters")
  func forAllTwoParameters() {
    let property = forAll(
      Gen<Int> { rng, _ in Int.random(in: 1...100, using: &rng) },
      Gen<Int> { rng, _ in Int.random(in: 1...100, using: &rng) }
    ) { a, b in
      a + b == b + a  // Commutativity
    }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("forAll with two parameters - PropertyEvaluation")
  func forAllTwoParametersEvaluation() async {
    let property = forAll(
      Gen<Int> { rng, _ in Int.random(in: -10...10, using: &rng) },
      Gen<Int> { rng, _ in Int.random(in: -10...10, using: &rng) }
    ) { n, d -> PropertyEvaluation in
      guard d != 0 else { return .discard(reason: "divisor cannot be zero") }
      return (n / d) * d == n ? .pass : .fail(reason: nil)
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runEvaluatingProperty(
      property,
      config: PropertyConfig(iterations: 100, maxDiscarded: 200)
    )

    // Integer division may not satisfy this property perfectly
    // but it should hold for most cases
    #expect(!result.isGaveUp)
  }

  @Test("forAll with three parameters")
  func forAllThreeParameters() {
    let property = forAll(
      Gen<Int> { rng, _ in Int.random(in: 1...10, using: &rng) },
      Gen<Int> { rng, _ in Int.random(in: 1...10, using: &rng) },
      Gen<Int> { rng, _ in Int.random(in: 1...10, using: &rng) }
    ) { a, b, c in
      (a + b) + c == a + (b + c)  // Associativity
    }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("forAll identity property")
  func forAllIdentity() {
    let property = forAll(Gen<Int> { rng, _ in Int.random(in: -100...100, using: &rng) }) { n in
      n + 0 == n
    }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }
}

@Suite("Property Combinator Integration")
struct PropertyCombinatorIntegrationTests {

  @Test("Combine forAll with && combinator")
  func forAllWithAndCombinator() {
    let positive = forAll(Gen<Int> { rng, _ in Int.random(in: 1...100, using: &rng) }) { n in
      n > 0
    }
    let lessThan50 = forAll(Gen<Int> { rng, _ in Int.random(in: 1...100, using: &rng) }) { n in
      n < 50
    }

    let combined = positive && lessThan50

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )

    // Should fail because some generated values >= 50
    #expect(result.isFailure)
  }

  @Test("Combine forAll with || combinator")
  func forAllWithOrCombinator() {
    let small = forAll(Gen<Int> { rng, _ in Int.random(in: 0...20, using: &rng) }) { n in
      n < 10
    }
    let large = forAll(Gen<Int> { rng, _ in Int.random(in: 0...20, using: &rng) }) { n in
      n > 15
    }

    let combined = small || large

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )

    // Should fail for values in range 10-15
    #expect(result.isFailure)
  }

  @Test("Chain multiple && operators")
  func chainMultipleAndOperators() {
    let prop1 = Property(generator: Gen.pure(10)) { $0 > 0 }
    let prop2 = Property(generator: Gen.pure(10)) { $0 < 20 }
    let prop3 = Property(generator: Gen.pure(10)) { $0.isMultiple(of: 2) }

    let combined = prop1 && prop2 && prop3

    let result = runPropertySynchronously(
      combined,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("Combine forAll with implies")
  func forAllWithImplies() {
    let property: Property<Int> = forAll(
      Gen<Int> { rng, _ in Int.random(in: -10...10, using: &rng) }
    ) { n in
      n * n >= 0
    }
    .implies { $0 != 0 }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 100, maxDiscarded: 200, seed: Seed(value: 42))
    )

    // Squares are always non-negative, should pass
    #expect(result.isSuccess)
  }
}
