import Testing
@testable import InvariantSwiftCore
@testable import InvariantSwift

// MARK: - PropertyResult Enhancement Tests

@Suite("PropertyResult Enhancements")
struct PropertyResultEnhancementTests {

  // MARK: - isGaveUp Tests

  @Test("isGaveUp returns true for gaveUp result")
  func testIsGaveUpTrue() {
    let result: PropertyResult<Int> = .gaveUp(discarded: 100, iterations: 50)
    #expect(result.isGaveUp == true)
    #expect(result.isSuccess == false)
    #expect(result.isFailure == false)
  }

  @Test("isGaveUp returns false for success result")
  func testIsGaveUpFalseForSuccess() {
    let result: PropertyResult<Int> = .success(iterations: 100)
    #expect(result.isGaveUp == false)
  }

  @Test("isGaveUp returns false for failure result")
  func testIsGaveUpFalseForFailure() {
    let result: PropertyResult<Int> = .failure(
      counterexample: 42,
      iterations: 10,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 123)
    )
    #expect(result.isGaveUp == false)
  }

  // MARK: - iterationCount Tests

  @Test("iterationCount extracts from success")
  func testIterationCountSuccess() {
    let result: PropertyResult<Int> = .success(iterations: 100)
    #expect(result.iterationCount == 100)
  }

  @Test("iterationCount extracts from failure")
  func testIterationCountFailure() {
    let result: PropertyResult<Int> = .failure(
      counterexample: 5,
      iterations: 42,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 1)
    )
    #expect(result.iterationCount == 42)
  }

  @Test("iterationCount extracts from gaveUp")
  func testIterationCountGaveUp() {
    let result: PropertyResult<Int> = .gaveUp(discarded: 50, iterations: 30)
    #expect(result.iterationCount == 30)
  }

  // MARK: - toExitCode Tests

  @Test("toExitCode returns 0 for success")
  func testExitCodeSuccess() {
    let result: PropertyResult<Int> = .success(iterations: 100)
    #expect(result.toExitCode() == 0)
  }

  @Test("toExitCode returns 1 for failure")
  func testExitCodeFailure() {
    let result: PropertyResult<Int> = .failure(
      counterexample: 5,
      iterations: 10,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 1)
    )
    #expect(result.toExitCode() == 1)
  }

  @Test("toExitCode returns 2 for gaveUp")
  func testExitCodeGaveUp() {
    let result: PropertyResult<Int> = .gaveUp(discarded: 50, iterations: 30)
    #expect(result.toExitCode() == 2)
  }

  // MARK: - Description Tests

  @Test("description contains checkmark for success")
  func testDescriptionSuccess() {
    let result: PropertyResult<Int> = .success(iterations: 100)
    #expect(result.description.contains("✓"))
    #expect(result.description.contains("100"))
  }

  @Test("description contains X for failure")
  func testDescriptionFailure() {
    let result: PropertyResult<Int> = .failure(
      counterexample: 5,
      iterations: 10,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 123)
    )
    #expect(result.description.contains("✗"))
    #expect(result.description.contains("123"))
  }

  @Test("shortDescription is concise")
  func testShortDescription() {
    let success: PropertyResult<Int> = .success(iterations: 100)
    let failure: PropertyResult<Int> = .failure(
      counterexample: 5,
      iterations: 10,
      shrunk: 1,
      reason: .predicateFailed,
      seed: Seed(value: 1)
    )
    let gaveUp: PropertyResult<Int> = .gaveUp(discarded: 50, iterations: 30)

    #expect(success.shortDescription == "PASS (100 iterations)")
    #expect(failure.shortDescription == "FAIL")
    #expect(gaveUp.shortDescription == "GAVE_UP (50 discarded)")
  }
}

// MARK: - Property Combinator Tests

@Suite("Property Combinators")
struct PropertyCombinatorTests {

  @Test("mapPredicate transforms predicate")
  func testMapPredicate() {
    let gen = Gen<Int> { rng, _ in Int.random(in: 0..<100, using: &rng) }
    let prop = Property(generator: gen) { $0 > 50 }

    // Invert the predicate
    let inverted = prop.mapPredicate { predicate in
      { value in !predicate(value) }
    }

    // Run both to verify they behave oppositely
    let result1 = runPropertySynchronously(
      prop,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )
    let result2 = runPropertySynchronously(
      inverted,
      config: PropertyConfig(iterations: 10, seed: Seed(value: 42))
    )

    // At least one should fail (they test opposite conditions)
    #expect(result1.isFailure || result2.isFailure)
  }

  @Test("mapGenerator transforms generator")
  func testMapGenerator() {
    let gen = Gen<Int> { rng, _ in Int.random(in: -100..<100, using: &rng) }
    let prop = Property(generator: gen) { $0 >= 0 }

    // Make all values non-negative
    let nonNegative = prop.mapGenerator { gen in
      gen.map { abs($0) }
    }

    let result = runPropertySynchronously(
      nonNegative,
      config: PropertyConfig(iterations: 100, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("filter restricts generated values")
  func testFilter() {
    let gen = Gen<Int> { rng, _ in Int.random(in: 0..<100, using: &rng) }
    let prop = Property(generator: gen) { $0 < 50 }

    // Filter to only test values < 30
    let filtered = prop.filter { $0 < 30 }

    let result = runPropertySynchronously(
      filtered,
      config: PropertyConfig(iterations: 50, seed: Seed(value: 42))
    )
    #expect(result.isSuccess)
  }

  @Test("label creates LabeledProperty")
  func testLabel() {
    let gen = Gen<Int> { rng, _ in Int.random(in: 0..<100, using: &rng) }
    let prop = Property(generator: gen) { $0 >= 0 }

    let labeled = prop.label("non-negative integers")

    #expect(labeled.label == "non-negative integers")
    #expect(labeled.property.predicate(50) == true)
  }
}

// MARK: - PropertyConfig Enhancement Tests

@Suite("PropertyConfig Enhancements")
struct PropertyConfigEnhancementTests {

  @Test("timeout field exists and is optional")
  func testTimeoutField() {
    let configWithTimeout = PropertyConfig(timeout: 5.0)
    let configWithoutTimeout = PropertyConfig()

    #expect(configWithTimeout.timeout == 5.0)
    #expect(configWithoutTimeout.timeout == nil)
  }

  @Test("verbosity field defaults to normal")
  func testVerbosityDefault() {
    let config = PropertyConfig()
    #expect(config.verbosity == .normal)
  }

  @Test("verbosity can be set to all levels")
  func testVerbosityLevels() {
    let silent = PropertyConfig(verbosity: .silent)
    let normal = PropertyConfig(verbosity: .normal)
    let verbose = PropertyConfig(verbosity: .verbose)

    #expect(silent.verbosity == .silent)
    #expect(normal.verbosity == .normal)
    #expect(verbose.verbosity == .verbose)
  }
}
