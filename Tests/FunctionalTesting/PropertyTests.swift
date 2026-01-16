import Testing
import Foundation
@testable import InvariantSwift

/// Comprehensive tests for Property functions to achieve 99%+ code coverage
struct PropertyTests {

  // MARK: - Property Creation Tests

  @Test("Property basic initialization")
  func propertyBasicInitialization() async {
    let property = Property<Int>(generator: Gen.int) { $0 > -1_000_000 }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property should pass for most ints, failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Property test gave up unexpectedly")
    }
  }

  @Test("Property with assumption initialization")
  func propertyWithAssumptionInitialization() async {
    let property = Property<Int>(
      generator: Gen.int,
      assumption: { $0 > 0 },  // Only test positive numbers
      predicate: { $0 > 0 }  // Positive numbers should be positive
    )
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property with assumption failed with: \(counterexample)")

    case .gaveUp:
      // Can happen if assumption filters too many values
      break
    }
  }

  // MARK: - PropertyResult enum tests

  @Test("PropertyResult success case")
  func propertyResultSuccessCase() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }  // Always pass
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .success(let iterations):
      #expect(iterations == 20, "Success should report correct iteration count")

    case .failure:
      Issue.record("Property that always passes should not fail")

    case .gaveUp:
      Issue.record("Property that always passes should not give up")
    }
  }

  @Test("PropertyResult failure case")
  func propertyResultFailureCase() async {
    let property = Property<Int>(generator: Gen.int(in: 1...100)) { $0 > 50 }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      // Might not fail if we don't generate values <= 50
      break

    case .failure(let counterexample, let iterations, let shrunk, _, _):
      #expect(counterexample > 0, "Counterexample should be in valid range")
      #expect(iterations > 0, "Should report positive iterations")
      #expect(shrunk <= counterexample, "Shrunk value should be <= original")

    case .gaveUp:
      Issue.record("Property failure test gave up unexpectedly")
    }
  }

  // MARK: - PropertyConfig Tests

  @Test("PropertyConfig initialization and validation")
  func propertyConfigInitializationAndValidation() async {
    // Test default config
    let defaultConfig = PropertyConfig.default
    #expect(defaultConfig.iterations == 100)
    #expect(defaultConfig.maxShrinks == 1000)
    #expect(defaultConfig.maxDiscarded == 1000)
    #expect(defaultConfig.seed == nil)

    // Test custom config with valid values
    let customConfig = PropertyConfig(
      iterations: 50,
      maxShrinks: 100,
      maxDiscarded: 200,
      seed: Seed(value: 12345)
    )
    #expect(customConfig.iterations == 50)
    #expect(customConfig.maxShrinks == 100)
    #expect(customConfig.maxDiscarded == 200)
    #expect(customConfig.seed == Seed(value: 12345))

    // Test config with invalid values (should be clamped)
    let clampedConfig = PropertyConfig(iterations: -10, maxShrinks: -5, maxDiscarded: -20)
    #expect(clampedConfig.iterations == 1, "Iterations should be clamped to minimum 1")
    #expect(clampedConfig.maxShrinks == 0, "MaxShrinks should be clamped to minimum 0")
    #expect(clampedConfig.maxDiscarded == 0, "MaxDiscarded should be clamped to minimum 0")
  }

  @Test("PropertyConfig with seeded randomness")
  func propertyConfigWithSeededRandomness() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }
    let seed = Seed(value: 98765)
    let config1 = PropertyConfig(iterations: 20, seed: seed)
    let config2 = PropertyConfig(iterations: 20, seed: seed)

    let runner1 = PropertyRunner(seed: seed)
    let runner2 = PropertyRunner(seed: seed)

    let result1 = await runner1.runProperty(property, config: config1)
    let result2 = await runner2.runProperty(property, config: config2)

    // Both should succeed with deterministic results
    switch (result1, result2) {
    case (.success(let iter1), .success(let iter2)):
      #expect(iter1 == iter2, "Seeded runs should be deterministic")

    default:
      break
    }
  }

  // MARK: - SeededRandomNumberGenerator Tests

  @Test("SeedBasedRandomNumberGenerator behavior")
  func seededRandomNumberGeneratorBehavior() async {
    var rng1 = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    var rng2 = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))

    // Same seed should produce same sequence
    let value1a = rng1.next()
    let value1b = rng1.next()

    let value2a = rng2.next()
    let value2b = rng2.next()

    #expect(value1a == value2a, "Same seed should produce same first value")
    #expect(value1b == value2b, "Same seed should produce same second value")

    // Zero seed should be handled
    var rngZero = SeedBasedRandomNumberGenerator(seed: Seed(value: 0))
    let zeroValue = rngZero.next()
    #expect(zeroValue != 0, "Zero seed should not produce zero state")
  }

  // MARK: - PropertyRunner Tests

  @Test("PropertyRunner with specific seed")
  func propertyRunnerWithSpecificSeed() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }

    let runner1 = PropertyRunner(seed: Seed(value: 555))
    let runner2 = PropertyRunner(seed: Seed(value: 555))

    let result1 = await runner1.runProperty(property, config: PropertyConfig(iterations: 10))
    let result2 = await runner2.runProperty(property, config: PropertyConfig(iterations: 10))

    // Both should succeed (deterministic with same seed)
    switch (result1, result2) {
    case (.success, .success):
      break

    default:
      Issue.record("Seeded property runners should produce consistent results")
    }
  }

  @Test("PropertyRunner without seed (system random)")
  func propertyRunnerWithoutSeed() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }

    let runner = PropertyRunner()  // Uses system random
    let result = await runner.runProperty(property, config: PropertyConfig(iterations: 20))

    switch result {
    case .success: break

    case .failure:
      Issue.record("Simple property should not fail")

    case .gaveUp:
      Issue.record("Simple property should not give up")
    }
  }

  // MARK: - Property Convenience Methods Tests

  @Test("Property.check convenience method")
  func propertyCheckConvenienceMethod() async {
    let property = Property.check(Gen.int) { $0 > Int.min }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property.check failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Property.check gave up unexpectedly")
    }
  }

  @Test("Property.implies convenience method")
  func propertyImpliesConvenienceMethod() async {
    // If x > 0, then x * 2 > 0
    let property = Property.implies(
      Gen.int,
      assumption: { $0 > 0 },
      conclusion: { $0 * 2 > 0 }
    )
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property.implies failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Property.implies gave up unexpectedly")
    }
  }

  @Test("Property.implies with false assumption")
  func propertyImpliesWithFalseAssumption() async {
    // If x < 0, then x > 100 (implication is vacuously true for non-negative x)
    let property = Property.implies(
      Gen.int(in: 0...50),  // Only generates non-negative, so assumption is always false
      assumption: { $0 < 0 },
      conclusion: { $0 > 100 }
    )
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break  // Should succeed because implication with false assumption is always true
    case .failure(let counterexample, _, _, _, _):
      Issue.record("Vacuous implication should not fail with: \(counterexample)")

    case .gaveUp:
      Issue.record("Vacuous implication should not give up")
    }
  }

  // MARK: - Property Combinator Tests

  @Test("Property and combinator")
  func propertyAndCombinator() async {
    let prop1 = Property<Int>(generator: Gen.int(in: 1...100)) { $0 > 0 }
    let prop2 = Property<String>(generator: Gen.string) { !$0.isEmpty || $0.isEmpty }  // Always true

    let combined = prop1.and(prop2)
    let result = await PropertyRunner().runProperty(
      combined,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property and combinator failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Property and combinator gave up unexpectedly")
    }
  }

  @Test("Property or combinator")
  func propertyOrCombinator() async {
    let prop1 = Property<Int>(generator: Gen.int) { $0 > 1_000_000 }  // Often false
    let prop2 = Property<String>(generator: Gen.string) { _ in true }  // Always true

    let combined = prop1.or(prop2)
    let result = await PropertyRunner().runProperty(
      combined,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break  // Should succeed because prop2 is always true
    case .failure(let counterexample, _, _, _, _):
      Issue.record("Property or combinator failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Property or combinator gave up unexpectedly")
    }
  }

  // MARK: - PropertyChecker Synchronous Tests

  @Test("PropertyChecker synchronous check")
  func propertyCheckerSynchronousCheck() async {
    let property = Property<Int>(generator: Gen.int) { $0 > Int.min }
    let result = runPropertySynchronously(property, config: PropertyConfig(iterations: 20))

    switch result {
    case .success(let iterations):
      #expect(iterations == 20, "Should complete all iterations")

    case .failure(let counterexample, _, _, _, _):
      Issue.record("PropertyChecker failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("PropertyChecker gave up unexpectedly")
    }
  }

  @Test("PropertyChecker with seeded config")
  func propertyCheckerWithSeededConfig() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }
    let config = PropertyConfig(iterations: 15, seed: Seed(value: 777))

    let result1 = runPropertySynchronously(property, config: config)
    let result2 = runPropertySynchronously(property, config: config)

    // Both should succeed with same config
    switch (result1, result2) {
    case (.success(let iter1), .success(let iter2)):
      #expect(iter1 == iter2, "Same config should produce same results")

    default:
      Issue.record("PropertyChecker with seeded config should be deterministic")
    }
  }

  @Test("PropertyChecker shrinking behavior")
  func propertyCheckerShrinkingBehavior() async {
    // Property that fails for numbers >= 10
    let property = Property<Int>(generator: Gen.int(in: 0...50)) { $0 < 10 }
    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 100, maxShrinks: 50)
    )

    switch result {
    case .success:
      // Might not generate values >= 10
      break

    case .failure(let counterexample, let iterations, let shrunk, _, _):
      #expect(counterexample >= 10, "Counterexample should be >= 10")
      #expect(shrunk >= 10, "Shrunk value should still fail the property")
      #expect(shrunk <= counterexample, "Shrunk should be <= original")
      #expect(iterations > 0, "Should have positive iterations")

    case .gaveUp:
      Issue.record("PropertyChecker shrinking test gave up")
    }
  }

  // MARK: - Shrinking Algorithm Tests

  @Test("Shrinking finds minimal counterexample")
  func shrinkingFindsMinimalCounterexample() async {
    // Property: no number is equal to 7
    let property = Property<Int>(generator: Gen.int(in: 0...20)) { $0 != 7 }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100, maxShrinks: 100)
    )

    switch result {
    case .success:
      // Might not generate 7
      break

    case .failure(let original, _, let shrunk, _, _):
      if original == 7 {
        // Original was already minimal
        #expect(shrunk == 7, "Shrunk should be 7 when original is 7")
      } else {
        // Should shrink towards a failure
        #expect(shrunk == 7, "Should shrink to find 7")
      }

    case .gaveUp:
      Issue.record("Shrinking test gave up")
    }
  }

  @Test("Shrinking with maxShrinks limit")
  func shrinkingWithMaxShrinksLimit() async {
    let property = Property<Int>(generator: Gen.int(in: 100...200)) { $0 < 50 }  // Will always fail
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 5, maxShrinks: 2)
    )

    switch result {
    case .success:
      Issue.record("Property should fail")

    case .failure(let original, _, let shrunk, _, _):
      #expect(original >= 100, "Original should be in range")
      #expect(shrunk >= 100, "With limited shrinking, may not shrink much")

    case .gaveUp:
      Issue.record("Property should fail, not give up")
    }
  }

  // MARK: - Size Parameter Effect Tests

  @Test("Size parameter affects generation")
  func sizeParameterAffectsGeneration() async {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { array in
      // Test that arrays don't exceed reasonable bounds based on size
      array.count <= 200  // Very generous upper bound
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Size parameter test failed with array of size: \(counterexample.count)")

    case .gaveUp:
      Issue.record("Size parameter test gave up")
    }
  }

  // MARK: - Edge Case and Error Handling Tests

  @Test("Property with always failing predicate")
  func propertyWithAlwaysFailingPredicate() async {
    let property = Property<Int>(generator: Gen.int) { _ in false }  // Always fails
    let result = await PropertyRunner().runProperty(property, config: PropertyConfig(iterations: 5))

    switch result {
    case .success:
      Issue.record("Always failing property should not succeed")

    case .failure(_, let iterations, _, _, _):
      #expect(iterations == 1, "Should fail on first iteration")

    case .gaveUp:
      Issue.record("Always failing property should fail, not give up")
    }
  }

  @Test("Property with maximum iterations")
  func propertyWithMaximumIterations() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 10000)
    )

    switch result {
    case .success(let iterations):
      #expect(iterations == 10000, "Should complete all iterations")

    case .failure:
      Issue.record("Always passing property should not fail")

    case .gaveUp:
      Issue.record("Always passing property should not give up")
    }
  }
}
