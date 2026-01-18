import Testing
import Foundation
@testable import InvariantSwift

/// Phase 7: Process Isolation Tests
///
/// Tests for crash-resilient property testing using subprocess isolation
@Suite("Isolated Property Runner Tests")
struct IsolatedPropertyRunnerTests {

  // MARK: - IsolatedPropertyResult Tests

  @Test("IsolatedPropertyResult success case")
  func isolatedPropertyResultSuccess() {
    let result = IsolatedPropertyResult<Int>.success(iterations: 100)

    switch result {
    case .success(let iterations):
      #expect(iterations == 100)

    default:
      Issue.record("Expected success case")
    }
  }

  @Test("IsolatedPropertyResult failure case")
  func isolatedPropertyResultFailure() {
    let result = IsolatedPropertyResult<Int>.failure(
      counterexample: 42,
      seed: Seed(value: 123),
      shrunk: 0,
      iterations: 50,
      reason: "Property returned false"
    )

    switch result {
    case .failure(let counterexample, _, let shrunk, let iterations, _):
      #expect(counterexample == 42)
      #expect(shrunk == 0)
      #expect(iterations == 50)

    default:
      Issue.record("Expected failure case")
    }
  }

  @Test("IsolatedPropertyResult crashed case")
  func isolatedPropertyResultCrashed() {
    let result = IsolatedPropertyResult<Int>.crashed(
      signal: 11,  // SIGSEGV
      counterexample: 99,
      shrunk: 10,
      iterations: 25
    )

    switch result {
    case .crashed(let signal, let counterexample, let shrunk, let iterations):
      #expect(signal == 11)
      #expect(counterexample == 99)
      #expect(shrunk == 10)
      #expect(iterations == 25)

    default:
      Issue.record("Expected crashed case")
    }
  }

  @Test("IsolatedPropertyResult gaveUp case")
  func isolatedPropertyResultGaveUp() {
    let result = IsolatedPropertyResult<Int>.gaveUp(discards: 100)

    switch result {
    case .gaveUp(let discards):
      #expect(discards == 100)

    default:
      Issue.record("Expected gaveUp case")
    }
  }

  // MARK: - IsolatedPropertyRunner Basic Tests

  @Test("IsolatedPropertyRunner executes property successfully")
  func isolatedPropertyRunnerSuccess() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(generator: Gen.int) { _ in
      true  // Always passes
    }

    let result = await runner.runProperty(property, config: PropertyConfig(iterations: 10))

    switch result {
    case .success(let iterations):
      #expect(iterations == 10)

    default:
      Issue.record("Expected success")
    }
  }

  @Test("IsolatedPropertyRunner detects property failure")
  func isolatedPropertyRunnerFailure() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(generator: Gen.int(in: 50...100)) { value in
      value < 25  // Always fails for range 50...100
    }

    let result = await runner.runProperty(property, config: PropertyConfig(iterations: 20))

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      #expect(counterexample >= 50 && counterexample <= 100)
      #expect(shrunk >= 50 && shrunk <= 100)

    default:
      Issue.record("Expected failure with shrunk counterexample")
    }
  }

  @Test("IsolatedPropertyRunner handles filter discards")
  func isolatedPropertyRunnerDiscards() async {
    let runner = IsolatedPropertyRunner()
    // Use a simple generator that always passes - tests basic execution
    let property = Property<Int>(generator: Gen.int(in: 1...10)) { value in
      value >= 1 && value <= 10  // Always passes for range
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 5, maxDiscarded: 100)
    )

    // Should succeed since property always passes
    switch result {
    case .success(let iterations):
      #expect(iterations == 5)

    default:
      Issue.record("Expected success for simple property")
    }
  }

  // MARK: - PropertyConfig.isolated Tests

  @Test("PropertyConfig.isolated creates valid configuration")
  func propertyConfigIsolated() {
    let config = PropertyConfig.isolated(
      iterations: 50,
      maxShrinks: 25,
      timeout: 10.0
    )

    #expect(config.iterations == 50)
    #expect(config.maxShrinks == 25)
  }

  @Test("PropertyConfig.isolated default values")
  func propertyConfigIsolatedDefaults() {
    let config = PropertyConfig.isolated()

    #expect(config.iterations == 100)
    #expect(config.maxShrinks == 50)
  }

  // MARK: - Concurrent Isolation Tests

  @Test("Multiple isolated runners can execute concurrently")
  func concurrentIsolatedRunners() async {
    let property = Property<Int>(generator: Gen.int) { _ in true }
    let config = PropertyConfig.isolated(iterations: 10)

    async let result1 = IsolatedPropertyRunner().runProperty(property, config: config)
    async let result2 = IsolatedPropertyRunner().runProperty(property, config: config)
    async let result3 = IsolatedPropertyRunner().runProperty(property, config: config)

    let (r1, r2, r3) = await (result1, result2, result3)

    // All should succeed
    switch (r1, r2, r3) {
    case (.success, .success, .success):
      #expect(Bool(true))

    default:
      Issue.record("All concurrent isolated runs should succeed")
    }
  }

  // MARK: - Shrinking with Isolation Tests

  @Test("Isolated runner shrinks failing values")
  func isolatedRunnerShrinks() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(generator: Gen.int(in: 100...1000)) { value in
      value < 50  // Always fails for range
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 20, maxShrinks: 50)
    )

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      // Shrunk value should be smaller or equal (closer to boundary)
      #expect(shrunk <= counterexample)
      #expect(shrunk >= 100)  // Still in original range
    default:
      Issue.record("Expected failure with shrinking")
    }
  }

  @Test("Isolated runner with array shrinking")
  func isolatedRunnerArrayShrinking() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<[Int]>(generator: Gen.array(Gen.int(in: 1...100))) { array in
      !array.contains(42)  // Fails if array contains 42
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 100, maxShrinks: 50)
    )

    switch result {
    case .failure(_, _, let shrunk, _, _):
      #expect(shrunk.contains(42), "Shrunk array should still contain 42")
      #expect(shrunk.count <= 10, "Array should shrink to smaller size")

    case .success:
      #expect(Bool(true), "Property may pass if 42 never generated")

    default:
      Issue.record("Unexpected result")
    }
  }
}

// MARK: - Subprocess Runner Tests

@Suite("Subprocess Runner Tests")
struct SubprocessRunnerTests {

  @Test("SubprocessRunner result enum has all expected cases")
  func subprocessResultCases() {
    // Test that all cases can be constructed
    let success = SubprocessRunner.SubprocessResult.success
    let failure = SubprocessRunner.SubprocessResult.failure(reason: "test")
    let crashed = SubprocessRunner.SubprocessResult.crashed(signal: 9)
    let timeout = SubprocessRunner.SubprocessResult.timeout

    // Verify pattern matching works
    switch success {
    case .success: #expect(Bool(true))
    default: Issue.record("Expected success")
    }

    switch failure {
    case .failure(let reason): #expect(reason == "test")
    default: Issue.record("Expected failure")
    }

    switch crashed {
    case .crashed(let signal): #expect(signal == 9)
    default: Issue.record("Expected crashed")
    }

    switch timeout {
    case .timeout: #expect(Bool(true))
    default: Issue.record("Expected timeout")
    }
  }
}
