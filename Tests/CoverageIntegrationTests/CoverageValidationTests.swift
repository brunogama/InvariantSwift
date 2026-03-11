import InvariantSwiftCore
import InvariantSwiftTesting
import Testing

@Suite("Coverage Validation Tests")
struct CoverageValidationTests {
  @Test("seeded generators remain deterministic across runs")
  func seededGeneratorsRemainDeterministicAcrossRuns() {
    var firstIntRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 1)
    )
    var secondIntRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 1)
    )
    var firstStringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 2)
    )
    var secondStringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 2)
    )

    let firstInt = Gen<Int>.int.generate(&firstIntRng, Size(value: 10))
    let secondInt = Gen<Int>.int.generate(&secondIntRng, Size(value: 10))
    let firstString = Gen<String>.string.generate(&firstStringRng, Size(value: 10))
    let secondString = Gen<String>.string.generate(&secondStringRng, Size(value: 10))

    #expect(firstInt == secondInt)
    #expect(firstString == secondString)
  }

  @Test("property runner reports a shrunk counterexample")
  func propertyRunnerReportsAShrunkCounterexample() async {
    let runner = PropertyRunner(seed: Seed(value: 41))
    let property = Property<Int>(
      generator: Gen.pure(8).withShrink { value in
        value > 0 ? [0, 4] : []
      },
      predicate: { $0 > 8 }
    )

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 1, maxShrinks: 10)
    )

    switch result {
    case .failure(let counterexample, let iterations, let shrunk, let reason, let seed):
      #expect(counterexample == 8)
      #expect(iterations == 1)
      #expect(shrunk == 0)
      #expect(reason == .predicateFailed)
      #expect(seed.rawValue == 41)

    case .success, .gaveUp:
      Issue.record("Expected a failing property with a shrunk counterexample")
    }
  }

  @Test("property runner gives up on discard heavy properties")
  func propertyRunnerGivesUpOnDiscardHeavyProperties() async {
    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runProperty(
      Property<Int>(
        generator: Gen<Int>.int,
        assumption: { _ in false },
        predicate: { _ in true }
      ),
      config: PropertyConfig(iterations: 3, maxDiscarded: 3)
    )

    switch result {
    case .gaveUp(let discarded, let iterations):
      #expect(discarded == 4)
      #expect(iterations == 0)

    case .success, .failure:
      Issue.record("Discard-heavy properties should report .gaveUp")
    }
  }

  @Test("public Swift Testing helpers accept passing properties")
  func publicSwiftTestingHelpersAcceptPassingProperties() async throws {
    let passingProperty = Property<String>(generator: Gen.pure("stable")) { value in
      !value.isEmpty
    }

    try await checkProperty(
      passingProperty,
      config: PropertyConfig(iterations: 1, seed: Seed(value: 9))
    )
    try await checkPropertyAsync(
      passingProperty,
      config: PropertyConfig(iterations: 1, seed: Seed(value: 10))
    )
  }

  @Test("property timeout returns a completed value before the deadline")
  func propertyTimeoutReturnsCompletedValueBeforeDeadline() async throws {
    let value = try await withPropertyTimeout(seconds: 1) {
      await Task.yield()
      return 7
    }

    #expect(value == 7)
  }
}
