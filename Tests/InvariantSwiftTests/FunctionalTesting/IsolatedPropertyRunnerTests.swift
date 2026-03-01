import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift

/// Phase 7 (updated for Plan 13-04): Isolated Property Runner Tests
///
/// Tests for crash-resilient property testing via the IsolationStrategy pattern.
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

  @Test("IsolatedPropertyResult crashed case carries CrashReport")
  func isolatedPropertyResultCrashed() {
    let report = CrashReport<Int>(
      signal: 11,
      counterexample: 99,
      shrunkCounterexample: 10,
      stderr: "",
      backtrace: [],
      isSymbolicated: false,
      isolationMechanism: .threadSignalHandler
    )
    let result = IsolatedPropertyResult<Int>.crashed(report: report, iterations: 25)

    switch result {
    case .crashed(let r, let iterations):
      #expect(r.signal == 11)
      #expect(r.counterexample == 99)
      #expect(r.shrunkCounterexample == 10)
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
    let property = Property<Int>(generator: Gen<Int>.int) { _ in
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
    let property = Property<Int>(generator: Gen<Int>.int(in: 50...100)) { value in
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

  @Test("IsolatedPropertyRunner handles simple passing property")
  func isolatedPropertyRunnerPassing() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<Int>(generator: Gen<Int>.int(in: 1...10)) { value in
      value >= 1 && value <= 10  // Always passes for range
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 5, maxDiscarded: 100)
    )

    switch result {
    case .success(let iterations):
      #expect(iterations == 5)

    default:
      Issue.record("Expected success for simple property")
    }
  }

  // MARK: - isolationCapability Tests

  @Test("IsolatedPropertyRunner exposes isolationCapability")
  func isolationCapabilityAccess() async {
    let runner = IsolatedPropertyRunner()
    let cap = await runner.isolationCapability
    // The capability must be a valid IsolationCapability value.
    // Verify CustomStringConvertible produces a non-empty string.
    #expect(!cap.description.isEmpty)
  }

  @Test("IsolatedPropertyRunner with PassthroughIsolation has .none capability")
  func isolationCapabilityPassthrough() async {
    let runner = IsolatedPropertyRunner(strategy: PassthroughIsolation())
    let cap = await runner.isolationCapability
    #expect(cap == .none)
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

    async let result1 = IsolatedPropertyRunner().runProperty(property, config: config)
    async let result2 = IsolatedPropertyRunner().runProperty(property, config: config)
    async let result3 = IsolatedPropertyRunner().runProperty(property, config: config)

    let (r1, r2, r3) = await (result1, result2, result3)

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
    let property = Property<Int>(generator: Gen<Int>.int(in: 100...1000)) { value in
      value < 50  // Always fails for range
    }

    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 20, maxShrinks: 50)
    )

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      #expect(shrunk <= counterexample)
      #expect(shrunk >= 100)

    default:
      Issue.record("Expected failure with shrinking")
    }
  }

  @Test("Isolated runner with array shrinking")
  func isolatedRunnerArrayShrinking() async {
    let runner = IsolatedPropertyRunner()
    let property = Property<[Int]>(
      generator: Gen<[Int]>.array(Gen<Int>.int(in: 1...100))
    ) { array in
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
