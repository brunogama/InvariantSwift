import Testing
import Foundation
@testable import InvariantSwift

/// Tests for E003: Timeout support making FailureReason.timedOut reachable
struct TimeoutTests {

  // MARK: - Timeout Enforcement

  @Test("runPropertyWithTimeout returns timedOut for slow predicates")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func runPropertyWithTimeoutReturnsTimedOut() async {
    let slowProperty = Property<Int>(generator: Gen<Int>.int(in: 0...100)) { _ in
      // Simulate slow predicate
      Thread.sleep(forTimeInterval: 0.5)
      return true
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let config = PropertyConfig(iterations: 1, timeout: 0.1)  // 100ms timeout

    let result = await runner.runPropertyWithTimeout(slowProperty, config: config)

    switch result {
    case .failure(_, _, _, let reason, _):
      if case .timedOut(let seconds) = reason {
        #expect(seconds == 0.1, "Timeout should match config")
      } else {
        Issue.record("Expected timedOut reason, got \(reason)")
      }

    case .success:
      Issue.record("Slow property should timeout, not succeed")

    case .gaveUp:
      Issue.record("Should not give up")
    }
  }

  @Test("runPropertyWithTimeout succeeds for fast predicates")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func runPropertyWithTimeoutSucceedsForFast() async {
    let fastProperty = Property<Int>(generator: Gen<Int>.int(in: 0...100)) { n in
      n >= 0  // Fast predicate
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let config = PropertyConfig(iterations: 10, timeout: 1.0)  // 1s timeout

    let result = await runner.runPropertyWithTimeout(fastProperty, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 10, "Should complete all iterations")

    case .failure:
      Issue.record("Fast property should not fail")

    case .gaveUp:
      Issue.record("Should not give up")
    }
  }

  @Test("runPropertyWithTimeout returns predicateFailed for normal failures")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func runPropertyWithTimeoutReturnsPredicateFailed() async {
    let failingProperty = Property<Int>(generator: Gen<Int>.int(in: 0...100)) { n in
      n < 50  // Will fail for values >= 50
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let config = PropertyConfig(iterations: 100, timeout: 1.0)

    let result = await runner.runPropertyWithTimeout(failingProperty, config: config)

    switch result {
    case .failure(_, _, _, let reason, _):
      #expect(reason == .predicateFailed, "Should be predicateFailed, not timedOut")

    case .success:
      Issue.record("Failing property should fail")

    case .gaveUp:
      Issue.record("Should not give up")
    }
  }

  // MARK: - FailureReason Reachability

  @Test("All FailureReason cases are reachable")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func allFailureReasonCasesReachable() async {
    // .predicateFailed - via normal property failure
    let failingProp = Property<Bool>(generator: Gen<Bool>.bool) { _ in false }
    let result1 = runPropertySynchronously(failingProp, config: PropertyConfig(iterations: 1))
    if case .failure(_, _, _, let reason, _) = result1 {
      #expect(reason == .predicateFailed, "predicateFailed should be reachable")
    }

    // .threwError - via ThrowingProperty
    struct TestError: Error {}
    let throwingProp = ThrowingProperty<Int>(generator: Gen<Int>.int) { _ in
      throw TestError()
    }
    let result2 = runThrowingPropertySynchronously(
      throwingProp,
      config: PropertyConfig(iterations: 1)
    )
    if case .failure(_, _, _, let reason, _) = result2 {
      if case .threwError = reason {
        #expect(Bool(true), "threwError should be reachable")
      } else {
        Issue.record("Expected threwError, got \(reason)")
      }
    }

    // .timedOut - via runPropertyWithTimeout with slow predicate
    let slowProp = Property<Int>(generator: Gen<Int>.int(in: 0...10)) { _ in
      Thread.sleep(forTimeInterval: 0.2)
      return true
    }
    let runner = PropertyRunner(seed: Seed(value: 42))
    let result3 = await runner.runPropertyWithTimeout(
      slowProp,
      config: PropertyConfig(iterations: 1, timeout: 0.05)
    )
    if case .failure(_, _, _, let reason, _) = result3 {
      if case .timedOut = reason {
        #expect(Bool(true), "timedOut should be reachable")
      } else {
        Issue.record("Expected timedOut, got \(reason)")
      }
    }
  }
}
