/// SchedulerTests - Comprehensive tests for the Scheduler types
///
/// Tests for Scheduler, InterleavingPath, InterleavingHeuristic, and SchedulerResult
/// from ISP-0001: Scheduler-Based Race Condition Testing

import Testing
import Foundation
@testable import InvariantSwiftCore
@testable import InvariantSwift
@testable import InvariantSwiftExperimental

@Suite("Scheduler Core Types")
struct SchedulerTests {

  // MARK: - Scheduler Strategy Tests

  @Test("Scheduler strategy random initialization")
  func testSchedulerStrategyRandom() {
    let strategy = Scheduler.Strategy.random(seed: 12345)

    if case .random(let seed) = strategy {
      #expect(seed == 12345)
    } else {
      Issue.record("Expected random strategy")
    }
  }

  @Test("Scheduler strategy exhaustive initialization")
  func testSchedulerStrategyExhaustive() {
    let strategy = Scheduler.Strategy.exhaustive(depth: 5)

    if case .exhaustive(let depth) = strategy {
      #expect(depth == 5)
    } else {
      Issue.record("Expected exhaustive strategy")
    }
  }

  @Test("Scheduler strategy replay initialization")
  func testSchedulerStrategyReplay() {
    let path = InterleavingPath(steps: [0, 1, 2])
    let strategy = Scheduler.Strategy.replay(path: path)

    if case .replay(let replayPath) = strategy {
      #expect(replayPath == path)
    } else {
      Issue.record("Expected replay strategy")
    }
  }

  @Test("Scheduler strategy equality")
  func testSchedulerStrategyEquality() {
    let random1 = Scheduler.Strategy.random(seed: 42)
    let random2 = Scheduler.Strategy.random(seed: 42)
    let random3 = Scheduler.Strategy.random(seed: 99)

    #expect(random1 == random2)
    #expect(random1 != random3)

    let exhaustive1 = Scheduler.Strategy.exhaustive(depth: 5)
    let exhaustive2 = Scheduler.Strategy.exhaustive(depth: 5)

    #expect(exhaustive1 == exhaustive2)
    #expect(random1 != exhaustive1)
  }

  // MARK: - Scheduler Initialization Tests

  @Test("Scheduler default initialization")
  func testSchedulerDefaultInit() {
    let scheduler = Scheduler()

    #expect(scheduler.maxInterleavings == 1000)
    #expect(scheduler.timeout == .seconds(30))
  }

  @Test("Scheduler custom initialization")
  func testSchedulerCustomInit() {
    let scheduler = Scheduler(
      strategy: .exhaustive(depth: 10),
      maxInterleavings: 500,
      timeout: .seconds(60)
    )

    #expect(scheduler.maxInterleavings == 500)
    #expect(scheduler.timeout == .seconds(60))
  }

  // MARK: - InterleavingPath Tests

  @Test("InterleavingPath initialization")
  func testInterleavingPathInit() {
    let path = InterleavingPath(steps: [0, 1, 2, 3])

    #expect(path.steps.count == 4)
    #expect(path.steps == [0, 1, 2, 3])
  }

  @Test("InterleavingPath description")
  func testInterleavingPathDescription() {
    let path = InterleavingPath(steps: [0, 1, 2])

    #expect(path.description == "0:1:2")
  }

  @Test("InterleavingPath empty description")
  func testInterleavingPathEmptyDescription() {
    let path = InterleavingPath(steps: [])

    #expect(path.description == "")
  }

  @Test("InterleavingPath appending")
  func testInterleavingPathAppending() {
    let path = InterleavingPath(steps: [0, 1])
    let extended = path.appending(step: 2)

    #expect(extended.steps == [0, 1, 2])
    #expect(path.steps == [0, 1])  // Original unchanged
  }

  @Test("InterleavingPath shrinking generates candidates")
  func testInterleavingPathShrinking() {
    let path = InterleavingPath(steps: [1, 2, 3])
    let candidates = path.shrink()

    // Should have candidates from removing steps and reducing values
    #expect(!candidates.isEmpty)

    // Removing one step should create 3 candidates
    let removalCandidates = candidates.filter { $0.steps.count == 2 }
    #expect(removalCandidates.count == 3)
  }

  @Test("InterleavingPath hashable conformance")
  func testInterleavingPathHashable() {
    let path1 = InterleavingPath(steps: [0, 1, 2])
    let path2 = InterleavingPath(steps: [0, 1, 2])
    let path3 = InterleavingPath(steps: [0, 1])

    #expect(path1 == path2)
    #expect(path1 != path3)

    let set: Set<InterleavingPath> = [path1, path2, path3]
    #expect(set.count == 2)
  }

  @Test("InterleavingPath codable conformance")
  func testInterleavingPathCodable() throws {
    let path = InterleavingPath(steps: [0, 1, 2, 3])

    let encoder = JSONEncoder()
    let data = try encoder.encode(path)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(InterleavingPath.self, from: data)

    #expect(decoded == path)
  }

  // MARK: - InterleavingHeuristic Tests

  @Test("InterleavingHeuristic maxContextSwitches")
  func testHeuristicMaxContextSwitches() {
    let heuristic = InterleavingHeuristic.maxContextSwitches
    let path = heuristic.nextPath(explored: [])

    #expect(path != nil)
    #expect((path?.steps.count ?? 0) > 0)
  }

  @Test("InterleavingHeuristic reverseCompletion")
  func testHeuristicReverseCompletion() {
    let heuristic = InterleavingHeuristic.reverseCompletion
    let path = heuristic.nextPath(explored: [])

    #expect(path != nil)
  }

  @Test("InterleavingHeuristic delay pattern")
  func testHeuristicDelayPattern() {
    let heuristic = InterleavingHeuristic.delay(pattern: "cache")
    let path = heuristic.nextPath(explored: [])

    #expect(path != nil)
  }

  @Test("InterleavingHeuristic actorBoundary")
  func testHeuristicActorBoundary() {
    let heuristic = InterleavingHeuristic.actorBoundary
    let path = heuristic.nextPath(explored: [])

    #expect(path != nil)
  }

  @Test("InterleavingHeuristic equality")
  func testHeuristicEquality() {
    let h1 = InterleavingHeuristic.maxContextSwitches
    let h2 = InterleavingHeuristic.maxContextSwitches
    let h3 = InterleavingHeuristic.reverseCompletion

    #expect(h1 == h2)
    #expect(h1 != h3)

    let delay1 = InterleavingHeuristic.delay(pattern: "test")
    let delay2 = InterleavingHeuristic.delay(pattern: "test")
    let delay3 = InterleavingHeuristic.delay(pattern: "other")

    #expect(delay1 == delay2)
    #expect(delay1 != delay3)
  }

  // MARK: - SchedulerResult Tests

  @Test("SchedulerResult success")
  func testSchedulerResultSuccess() {
    let result = SchedulerResult<Int>(
      interleavingsExplored: 100,
      failingPath: nil,
      error: nil,
      executionTime: .seconds(5)
    )

    #expect(result.isSuccess)
    #expect(result.interleavingsExplored == 100)
    #expect(result.failingPath == nil)
  }

  @Test("SchedulerResult failure")
  func testSchedulerResultFailure() {
    struct TestError: Error {}

    let path = InterleavingPath(steps: [0, 1, 2])
    let result = SchedulerResult<Int>(
      interleavingsExplored: 50,
      failingPath: path,
      error: TestError(),
      executionTime: .seconds(2)
    )

    #expect(!result.isSuccess)
    #expect(result.failingPath == path)
  }

  @Test("SchedulerResult summary contains interleavings")
  func testSchedulerResultSummary() {
    let result = SchedulerResult<Void>(
      interleavingsExplored: 42,
      failingPath: nil,
      error: nil,
      executionTime: .seconds(1)
    )

    let summary = result.summary()
    #expect(summary.contains("42"))
    #expect(summary.contains("passed"))
  }

  @Test("SchedulerResult summary shows failure path")
  func testSchedulerResultFailureSummary() {
    struct TestError: Error, CustomStringConvertible {
      var description: String { "Race condition" }
    }

    let path = InterleavingPath(steps: [0, 1])
    let result = SchedulerResult<Void>(
      interleavingsExplored: 10,
      failingPath: path,
      error: TestError(),
      executionTime: .seconds(0.5)
    )

    let summary = result.summary()
    #expect(summary.contains("Failure"))
    #expect(summary.contains("0:1"))
  }

  // MARK: - PendingOperation Tests

  @Test("PendingOperation initialization")
  func testPendingOperationInit() {
    let op = PendingOperation(name: "fetchData", priority: .high)

    #expect(op.name == "fetchData")
    #expect(op.priority == .high)
  }

  @Test("PendingOperation default values")
  func testPendingOperationDefaults() {
    let op = PendingOperation()

    #expect(op.name == "operation")
    #expect(op.priority == nil)
  }

  // MARK: - Scheduler nextInterleaving Tests

  @Test("Scheduler nextInterleaving random generates paths")
  func testSchedulerNextInterleavingRandom() {
    var scheduler = Scheduler(strategy: .random(seed: 42))

    let path1 = scheduler.nextInterleaving()
    let path2 = scheduler.nextInterleaving()

    #expect(path1 != nil)
    #expect(path2 != nil)
  }

  @Test("Scheduler nextInterleaving replay returns single path")
  func testSchedulerNextInterleavingReplay() {
    let expectedPath = InterleavingPath(steps: [0, 1, 2])
    var scheduler = Scheduler(strategy: .replay(path: expectedPath))

    let path1 = scheduler.nextInterleaving()
    #expect(path1 == expectedPath)

    // After first call, should return nil (single replay)
    let path2 = scheduler.nextInterleaving()
    #expect(path2 == nil)
  }

  @Test("Scheduler nextInterleaving exhaustive generates systematic paths")
  func testSchedulerNextInterleavingExhaustive() {
    var scheduler = Scheduler(
      strategy: .exhaustive(depth: 3),
      maxInterleavings: 10
    )

    var paths: [InterleavingPath] = []
    while let path = scheduler.nextInterleaving(), paths.count < 5 {
      paths.append(path)
    }

    #expect(paths.count == 5)
  }
}

// MARK: - Integration Tests

@Suite("Scheduler Integration")
struct SchedulerIntegrationTests {

  @Test("Scheduler run with simple async operation")
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  func testSchedulerRunSimple() async throws {
    var scheduler = Scheduler(
      strategy: .random(seed: 42),
      maxInterleavings: 5
    )

    let result = try await scheduler.run {
      await Task.yield()
      return 42
    }

    #expect(result.isSuccess)
    #expect(result.interleavingsExplored >= 1)
  }

  @Test("Scheduler detects simulated failure")
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  func testSchedulerDetectsFailure() async throws {
    struct SimulatedRaceCondition: Error {}

    var scheduler = Scheduler(
      strategy: .random(seed: 42),
      maxInterleavings: 10
    )

    // Use actor to safely track call count across concurrent executions
    actor CallCounter {
      var count = 0
      func increment() -> Int {
        count += 1
        return count
      }
    }
    let counter = CallCounter()

    let result: SchedulerResult<Void> = try await scheduler.run {
      let currentCount = await counter.increment()
      if currentCount == 3 {
        throw SimulatedRaceCondition()
      }
    }

    #expect(!result.isSuccess)
    #expect(result.failingPath != nil)
    #expect(result.interleavingsExplored == 3)
  }

  @Test("Scheduler respects timeout")
  @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *)
  func testSchedulerRespectsTimeout() async throws {
    var scheduler = Scheduler(
      strategy: .random(seed: 42),
      maxInterleavings: 1000,
      timeout: .milliseconds(100)
    )

    let startTime = ContinuousClock().now

    let result = try await scheduler.run {
      try? await Task.sleep(for: .milliseconds(10))
      return ()
    }

    let elapsed = ContinuousClock().now - startTime

    // Should complete before exploring all 1000 interleavings
    #expect(result.interleavingsExplored < 1000)
    #expect(elapsed < .seconds(10))
  }
}
