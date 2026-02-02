import Testing
import Foundation
@testable import InvariantCore
@testable import InvariantSwift

/// Dogfooding Tests: Failure Reporting Verification
///
/// These tests verify that failure reporting works correctly:
/// - ReproString includes all required information
/// - Human-readable messages are clear
/// - Seeds enable reproducibility
/// - Shrinking progress is visible
@Suite("Failure Reporting Tests")
struct FailureReportingTests {

  // MARK: - ReproString Tests

  @Test("ReproString includes seed for reproducibility")
  func reproStringIncludesSeed() {
    let property = Property<Int>(generator: Gen.int(in: 1...100)) { value in
      value < 10  // Will fail for most values
    }

    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(
        iterations: 100,
        seed: Seed(value: 12345)
      )
    )

    switch result {
    case .failure(_, _, _, _, let seed):
      #expect(seed.rawValue == 12345, "Seed should match configured seed")

    default:
      Issue.record("Expected failure but got \(result)")
    }
  }

  @Test("ReproString can be parsed and reconstructed")
  func reproStringRoundTrip() {
    let original = ReproString(
      seed: 42,
      iteration: 15,
      shrunkDescription: "[1, 2, 3]",
      reason: .predicateFailed
    )

    let stringForm = original.description
    let parsed = ReproString.parse(stringForm)

    #expect(parsed != nil, "Should parse successfully")
    if let parsed = parsed {
      #expect(parsed.seed == 42)
      #expect(parsed.iteration == 15)
      #expect(parsed.shrunkDescription == "[1, 2, 3]")
    }
  }

  @Test("ReproString parses timedOut reason correctly")
  func reproStringParseTimedOut() {
    let reproString = "REPRO:seed=123,iter=5,shrunk=\"value\",reason=timedOut(2.5s)"
    let parsed = ReproString.parse(reproString)

    #expect(parsed != nil)
    if let parsed = parsed {
      if case .timedOut(let seconds) = parsed.reason {
        #expect(seconds == 2.5)
      } else {
        Issue.record("Expected timedOut reason")
      }
    }
  }

  @Test("ReproString parses threwError reason correctly")
  func reproStringParseThrewError() {
    let reproString = "REPRO:seed=456,iter=10,shrunk=\"test\",reason=threwError(TestError)"
    let parsed = ReproString.parse(reproString)

    #expect(parsed != nil)
    if let parsed = parsed {
      if case .threwError(let error) = parsed.reason {
        #expect(error == "TestError")
      } else {
        Issue.record("Expected threwError reason")
      }
    }
  }

  // MARK: - PropertyResult Description Tests

  @Test("PropertyResult description is human-readable")
  func propertyResultDescriptionReadable() {
    let success: PropertyResult<Int> = .success(iterations: 100)
    #expect(success.description.contains("✓"))
    #expect(success.description.contains("100"))

    let gaveUp: PropertyResult<Int> = .gaveUp(discarded: 50, iterations: 30)
    #expect(gaveUp.description.contains("?"))
    #expect(gaveUp.description.contains("30"))
    #expect(gaveUp.description.contains("50"))
  }

  @Test("PropertyResult failure includes minimal counterexample")
  func propertyResultFailureIncludesMinimal() {
    let failure: PropertyResult<Int> = .failure(
      counterexample: 99,
      iterations: 5,
      shrunk: 42,
      reason: .predicateFailed,
      seed: Seed(value: 123)
    )

    let desc = failure.description
    #expect(desc.contains("42"), "Should show shrunk value: \(desc)")
    #expect(desc.contains("123"), "Should show seed: \(desc)")
  }

  // MARK: - Seed Reproducibility Tests

  @Test("Same seed reproduces same failure")
  func sameSeedReproducesSameFailure() {
    let property = Property<Int>(generator: Gen.int(in: 1...1000)) { value in
      value < 500
    }

    let seed = Seed(value: 98765)

    let result1 = runPropertySynchronously(
      property,
      config: PropertyConfig(
        iterations: 100,
        seed: seed
      )
    )

    let result2 = runPropertySynchronously(
      property,
      config: PropertyConfig(
        iterations: 100,
        seed: seed
      )
    )

    // Both should fail at the same value
    switch (result1, result2) {
    case (.failure(let c1, let i1, let s1, _, _), .failure(let c2, let i2, let s2, _, _)):
      #expect(c1 == c2, "Counterexamples should match")
      #expect(i1 == i2, "Iteration counts should match")
      #expect(s1 == s2, "Shrunk values should match")

    default:
      Issue.record("Both runs should fail identically")
    }
  }

  @Test("Different seeds produce different sequences")
  func differentSeedsProduceDifferentSequences() {
    let gen = Gen.int(in: 1...10000)
    let size = Size(value: 50)

    var valuesForSeed1: [Int] = []
    var valuesForSeed2: [Int] = []

    for i in 0..<10 {
      valuesForSeed1.append(gen.sample(size: size, seed: Seed(value: 1 + UInt64(i))))
      valuesForSeed2.append(gen.sample(size: size, seed: Seed(value: 1000 + UInt64(i))))
    }

    // The sequences should be different
    #expect(valuesForSeed1 != valuesForSeed2, "Different seeds should produce different sequences")
  }
}

// MARK: - Generator Distribution Tests

@Suite("Generator Distribution Tests")
struct GeneratorDistributionTests {

  @Test("oneOf produces fair distribution")
  func oneOfFairDistribution() {
    let gen = Gen.oneOf([Gen.pure(1), Gen.pure(2), Gen.pure(3)])
    var counts: [Int: Int] = [1: 0, 2: 0, 3: 0]

    for i in 0..<300 {
      let value = gen.sample(size: Size(value: 50), seed: Seed(value: UInt64(i)))
      counts[value, default: 0] += 1
    }

    // Each should appear roughly 100 times (±50% tolerance)
    for (value, count) in counts {
      #expect(count > 50, "Value \(value) should appear more than 50 times, got \(count)")
      #expect(count < 200, "Value \(value) should appear less than 200 times, got \(count)")
    }
  }

  @Test("frequency respects weights")
  func frequencyRespectsWeights() {
    // 90% chance of 1, 10% chance of 2
    let gen = Gen.frequency([(9, Gen.pure(1)), (1, Gen.pure(2))])
    var counts: [Int: Int] = [1: 0, 2: 0]

    for i in 0..<1000 {
      let value = gen.sample(size: Size(value: 50), seed: Seed(value: UInt64(i)))
      counts[value, default: 0] += 1
    }

    // 1 should appear ~900 times, 2 should appear ~100 times
    let ones = counts[1] ?? 0
    let twos = counts[2] ?? 0

    #expect(ones > 700, "1 should appear >700 times, got \(ones)")
    #expect(twos < 300, "2 should appear <300 times, got \(twos)")
    #expect(ones > twos * 3, "1 should appear 3x+ more than 2")
  }

  @Test("optional generator produces both nil and values")
  func optionalGeneratorProducesBothCases() {
    let gen = OptionalGen.optional(valueGen: Gen.int(in: 1...100), nilProbability: 0.3)
    var nilCount = 0
    var someCount = 0

    for i in 0..<200 {
      let value = gen.sample(size: Size(value: 50), seed: Seed(value: UInt64(i)))
      if value == nil {
        nilCount += 1
      } else {
        someCount += 1
      }
    }

    #expect(nilCount > 10, "Should produce some nils, got \(nilCount)")
    #expect(someCount > 10, "Should produce some values, got \(someCount)")
  }
}

// MARK: - Async Property Tests

@Suite("Async Property Shrinking Tests")
struct AsyncPropertyShrinkingTests {

  @Test("Async property applies shrinking")
  func asyncPropertyAppliesShrinking() async {
    let property = Property<Int>(generator: Gen.int(in: 50...1000)) { value in
      value < 100  // Will fail for values >= 100
    }

    let result = await runPropertyAsync(
      property,
      config: PropertyConfig(
        iterations: 100,
        maxShrinks: 1000,
        seed: Seed(value: 42)
      )
    )

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      #expect(
        shrunk <= counterexample,
        "Shrunk value should be <= original: \(shrunk) vs \(counterexample)"
      )
      #expect(shrunk >= 100, "Shrunk value should still fail: \(shrunk)")

    default:
      Issue.record("Expected failure but got \(result)")
    }
  }
}
