import Testing
import Darwin
import InvariantSwiftCore
@testable import InvariantSwift

/// Integration tests for crash isolation via IsolationStrategy.
///
/// The helper protocol remains covered separately, but full subprocess isolation
/// stays disabled until the helper can execute predicate closures. Darwin runners
/// use the closure-capable thread strategy in the meantime.
@Suite("Crash Isolation Integration Tests")
struct CrashIsolationIntegrationTests {

  @Test("IsolatedPropertyRunner survives subprocess execution without crash")
  func testSubprocessExecutionSurvives() async throws {
    // The subprocess path always returns .success (helper stub returns passed=true).
    // The point of this test is that the parent process survives and receives a result.
    let property = Property(generator: Gen<Int>.int) { _ in true }
    let runner = IsolatedPropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 5)
    )

    // Must not crash; any non-fatal result is acceptable.
    switch result {
    case .success, .failure, .gaveUp:
      #expect(Bool(true), "Parent process survived subprocess execution")

    case .crashed:
      // A crash here would indicate the parent was affected, which is a bug.
      Issue.record("Unexpected crash result — parent should never crash")
    }
  }

  @Test("IsolatedPropertyRunner detects a known property failure")
  func testPropertyFailureDetected() async throws {
    let property = Property(generator: Gen<Int>.int(in: 1...10)) { _ in false }
    let runner = IsolatedPropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    guard case .failure = result else {
      Issue.record("Expected the failing predicate to produce a failure")
      return
    }
  }

  @Test("IsolationCapability.current is a valid value")
  func testIsolationCapabilityIsValid() {
    let cap = IsolationCapability.current
    #expect(!cap.description.isEmpty)
  }

  @Test("IsolatedPropertyRunner.isolated() config creates correct config")
  func testIsolatedConfig() {
    let config = PropertyConfig.isolated(iterations: 10, maxShrinks: 20)
    #expect(config.iterations == 10)
    #expect(config.maxShrinks == 20)
  }
}
