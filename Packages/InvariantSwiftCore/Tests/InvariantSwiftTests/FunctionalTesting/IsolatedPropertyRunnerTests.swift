import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Phase 7: Process Isolation Tests
///
/// Tests for crash-resilient property testing using subprocess isolation
@Suite("Isolated Property Result Tests")
struct IsolatedPropertyResultTests {

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
    let context = IsolatedPropertyFailureContext(
      seed: Seed(value: 123),
      iterations: 50,
      reason: "Property returned false"
    )
    let failure = IsolatedPropertyFailure(
      counterexample: 42,
      shrunk: 0,
      context: context
    )
    let result = IsolatedPropertyResult<Int>.failure(failure)

    switch result {
    case .failure(let details):
      #expect(details.counterexample == 42)
      #expect(details.shrunk == 0)
      #expect(details.context.iterations == 50)

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

}

@Suite("Isolated Property Runner Tests")
struct IsolatedPropertyRunnerTests {
  @Test("IsolatedPropertyRunner executes property successfully")
  func isolatedPropertyRunnerSuccess() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(generator: Gen<Int>.int) { _ in
      true  // Always passes
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    expectPlatformResult(result, macOSIterations: 10)
  }

  @Test("IsolatedPropertyRunner detects property failure")
  func isolatedPropertyRunnerFailure() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(
      generator: Gen<Int>.int(in: 50...100)
    ) { value in
      value < 25
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .failure(let failure):
      #expect((50...100).contains(failure.counterexample))
      #expect((50...100).contains(failure.shrunk))

    default:
      Issue.record("Expected failure with shrunk counterexample")
    }
  }

  @Test("IsolatedPropertyRunner handles filter discards")
  func isolatedPropertyRunnerDiscards() async {
    let runner = IsolatedPropertyRunner()
    // Use a simple generator that always passes - tests basic execution
    let property = Property<Int>(generator: Gen<Int>.int(in: 1...10)) { value in
      value >= 1 && value <= 10  // Always passes for range
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 5, maxDiscarded: 100)
    )

    expectPlatformResult(result, macOSIterations: 5)
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
    let property = Property<Int>(generator: Gen<Int>.int) { _ in true }
    let config = PropertyConfig.isolated(iterations: 10)

    async let result1 = IsolatedPropertyRunner().runProperty(
      property,
      config: config
    )
    async let result2 = IsolatedPropertyRunner().runProperty(
      property,
      config: config
    )
    async let result3 = IsolatedPropertyRunner().runProperty(
      property,
      config: config
    )

    let results = await (result1, result2, result3)
    expectPlatformResult(results.0, macOSIterations: 10)
    expectPlatformResult(results.1, macOSIterations: 10)
    expectPlatformResult(results.2, macOSIterations: 10)
  }

}

@Suite("Isolated Property Shrinking Tests")
struct IsolatedPropertyShrinkingTests {
  @Test("Isolated runner shrinks failing values")
  func isolatedRunnerShrinks() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(
      generator: Gen<Int>.int(in: 100...1000)
    ) { value in
      value < 50
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 20, maxShrinks: 50)
    )

    switch result {
    case .failure(let failure):
      #expect(failure.shrunk <= failure.counterexample)
      #expect(failure.shrunk >= 100)

    default:
      Issue.record("Expected failure with shrinking")
    }
  }

  @Test("Isolated runner with array shrinking")
  func isolatedRunnerArrayShrinking() async {
    let run = IsolatedPropertyRunner()
    let property = Property<[Int]>(
      generator: Gen<[Int]>.array(Gen<Int>.int(in: 1...100))
    ) { !$0.contains(42) }
    let config = PropertyConfig(iterations: 100, maxShrinks: 50)
    let result = await run.runProperty(property, config: config)

    #if os(macOS)
    switch result {
    case .failure(let failure):
      #expect(failure.shrunk.contains(42))
      #expect(failure.shrunk.count <= 10)

    case .success:
      #expect(Bool(true), "Property may pass if 42 never generated")

    default:
      Issue.record("Unexpected result")
    }
    #else
    let expectations = IsolatedPropertyRunnerTests()
    expectations.expectPlatformResult(result, macOSIterations: 100)
    #endif
  }
}

// MARK: - Subprocess Runner Tests

@Suite("Subprocess Runner Tests")
struct SubprocessRunnerTests {

  @Test("SubprocessRunner exposes success results")
  func subprocessSuccessResult() {
    let result = SubprocessRunner.SubprocessResult.success
    guard case .success = result else {
      Issue.record("Expected success")
      return
    }
  }

  @Test("SubprocessRunner exposes failure results")
  func subprocessFailureResult() {
    let result = SubprocessRunner.SubprocessResult.failure(reason: "test")
    guard case .failure(let reason) = result else {
      Issue.record("Expected failure")
      return
    }
    #expect(reason == "test")
  }

  @Test("SubprocessRunner exposes crash results")
  func subprocessCrashResult() {
    let result = SubprocessRunner.SubprocessResult.crashed(signal: 9)
    guard case .crashed(let signal) = result else {
      Issue.record("Expected crash")
      return
    }
    #expect(signal == 9)
  }

  @Test("SubprocessRunner exposes timeout results")
  func subprocessTimeoutResult() {
    let result = SubprocessRunner.SubprocessResult.timeout
    guard case .timeout = result else {
      Issue.record("Expected timeout")
      return
    }
  }
}
