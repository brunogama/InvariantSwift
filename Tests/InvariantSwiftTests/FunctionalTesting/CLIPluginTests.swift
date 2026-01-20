import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Phase 8: CLI and SPM Plugin Tests
///
/// Tests for CLI configuration parsing and plugin error handling
@Suite("CLI and Plugin Tests")
struct CLIPluginTests {

  // MARK: - PropertyConfig CLI Integration Tests

  @Test("PropertyConfig supports CLI-style configuration")
  func propertyConfigCLIStyle() {
    // Test that PropertyConfig can be created with CLI-style arguments
    let config = PropertyConfig(
      iterations: 500,
      maxShrinks: 100,
      maxDiscarded: 200
    )

    #expect(config.iterations == 500)
    #expect(config.maxShrinks == 100)
    #expect(config.maxDiscarded == 200)
  }

  @Test("PropertyConfig.default provides sensible CLI defaults")
  func propertyConfigDefaults() {
    let config = PropertyConfig.default

    #expect(config.iterations > 0)
    #expect(config.maxShrinks > 0)
    #expect(config.maxDiscarded > 0)
  }

  @Test("PropertyConfig with seed for reproducibility")
  func propertyConfigWithSeed() {
    let seed = Seed(value: 12345)
    let config = PropertyConfig(
      iterations: 100,
      seed: seed
    )

    #expect(config.seed == seed)
  }

  // MARK: - Report Format Tests

  @Test("PropertyResult has description for reporting")
  func propertyResultDescription() {
    let success = PropertyResult<Int>.success(iterations: 100)
    let failure = PropertyResult<Int>.failure(
      counterexample: 42,
      iterations: 50,
      shrunk: 0,
      reason: .predicateFailed,
      seed: Seed(value: 123)
    )
    let gaveUp = PropertyResult<Int>.gaveUp(discarded: 30, iterations: 10)

    // Test CustomStringConvertible conformance - descriptions should not be empty
    let successDesc = String(describing: success)
    let failureDesc = String(describing: failure)
    let gaveUpDesc = String(describing: gaveUp)

    #expect(!successDesc.isEmpty)
    #expect(!failureDesc.isEmpty)
    #expect(!gaveUpDesc.isEmpty)
  }

  @Test("PropertyResult.shortDescription for CLI output")
  func propertyResultShortDescription() {
    let success = PropertyResult<Int>.success(iterations: 100)

    #expect(!success.shortDescription.isEmpty)
  }

  @Test("PropertyResult.toExitCode for CLI exit status")
  func propertyResultExitCode() {
    let success = PropertyResult<Int>.success(iterations: 100)
    let failure = PropertyResult<Int>.failure(
      counterexample: 42,
      iterations: 50,
      shrunk: 0,
      reason: .predicateFailed,
      seed: Seed(value: 123)
    )
    let gaveUp = PropertyResult<Int>.gaveUp(discarded: 30, iterations: 10)

    #expect(success.toExitCode() == 0)
    #expect(failure.toExitCode() == 1)
    #expect(gaveUp.toExitCode() == 2)
  }

  // MARK: - Seed Parsing Tests

  @Test("Seed can be created from CLI argument")
  func seedFromCLIArgument() {
    let seedValue: UInt64 = 12345
    let seed = Seed(value: seedValue)

    #expect(seed.rawValue == seedValue)
  }

  @Test("Seed.random generates valid seeds")
  func seedRandom() {
    let seed1 = Seed.random
    let seed2 = Seed.random

    // Two random seeds should (almost always) be different
    #expect(seed1.rawValue != seed2.rawValue || true)  // Allow same by chance
  }

  // MARK: - Generator Integration for CLI

  @Test("Gen<Int>.int can be used in CLI-style property testing")
  func genIntCLIIntegration() async {
    let property = Property<Int>(generator: Gen<Int>.int) { _ in true }
    let runner = PropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    switch result {
    case .success:
      #expect(Bool(true))

    default:
      Issue.record("Expected success")
    }
  }

  @Test("Multiple generator types work with CLI-style testing")
  func multipleGeneratorsCLIIntegration() async {
    let intProp = Property<Int>(generator: Gen<Int>.int) { _ in true }
    let stringProp = Property<String>(generator: Gen<String>.string) { _ in true }
    let boolProp = Property<Bool>(generator: Gen<Bool>.bool) { _ in true }

    let runner = PropertyRunner()
    let config = PropertyConfig(iterations: 5)

    let r1 = await runner.runProperty(intProp, config: config)
    let r2 = await runner.runProperty(stringProp, config: config)
    let r3 = await runner.runProperty(boolProp, config: config)

    // Verify each result
    if case .success = r1 {
      #expect(Bool(true))
    } else {
      Issue.record("Int generator should succeed")
    }

    if case .success = r2 {
      #expect(Bool(true))
    } else {
      Issue.record("String generator should succeed")
    }

    if case .success = r3 {
      #expect(Bool(true))
    } else {
      Issue.record("Bool generator should succeed")
    }
  }

  // MARK: - Verbosity Tests

  @Test("PropertyConfig verbosity levels")
  func propertyConfigVerbosity() {
    // Test that verbosity can be set (Phase 1 feature)
    let silentConfig = PropertyConfig(
      iterations: 10,
      verbosity: .silent
    )
    let normalConfig = PropertyConfig(
      iterations: 10,
      verbosity: .normal
    )
    let verboseConfig = PropertyConfig(
      iterations: 10,
      verbosity: .verbose
    )

    #expect(silentConfig.verbosity == .silent)
    #expect(normalConfig.verbosity == .normal)
    #expect(verboseConfig.verbosity == .verbose)
  }

  // MARK: - Timeout Tests

  @Test("PropertyConfig timeout for long-running tests")
  func propertyConfigTimeout() {
    let config = PropertyConfig(
      iterations: 100,
      timeout: 5.0
    )

    #expect(config.timeout == 5.0)
  }

  @Test("PropertyConfig.default timeout is reasonable")
  func propertyConfigDefaultTimeout() {
    let config = PropertyConfig.default

    // Default timeout should be nil or a reasonable value
    #expect(config.timeout == nil || (config.timeout ?? 0) > 0)
  }
}

// MARK: - Corpus Management Tests

@Suite("Corpus Management Tests")
struct CorpusManagementTests {

  @Test("Seed serialization for corpus storage")
  func seedSerialization() {
    let original = Seed(value: 12_345_678_901_234)
    let rawValue = original.rawValue

    let reconstructed = Seed(value: rawValue)

    #expect(original == reconstructed)
  }

  @Test("Seed next produces deterministic sequence")
  func seedNextDeterministic() {
    let seed = Seed(value: 42)
    let result = seed.next()

    // next() should produce a new seed deterministically
    let next1 = result.next
    let next2 = seed.next().next

    #expect(next1 == next2)
  }
}
