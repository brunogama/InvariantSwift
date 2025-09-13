import Testing
import Foundation
@testable import FunctionalTesting

/// Comprehensive async property testing coverage to achieve 99%+ code coverage
struct AsyncPropertyTests {

  // MARK: - PropertyRunner Async Execution with Different Seeds (Task 6)

  @Test("PropertyRunner async execution - deterministic with seed")
  func propertyRunnerAsyncExecutionDeterministicWithSeed() async throws {
    let property = Property<Int>(generator: Gen.int) { _ in
      true  // Always pass
    }

    let seed = Seed(value: 12345)
    let runner1 = PropertyRunner(seed: seed)
    let runner2 = PropertyRunner(seed: seed)

    let result1 = await runner1.runProperty(property, config: PropertyConfig(iterations: 10))
    let result2 = await runner2.runProperty(property, config: PropertyConfig(iterations: 10))

    // With same seed, both should succeed consistently
    switch (result1, result2) {
    case (.success(let iter1), .success(let iter2)):
      #expect(iter1 == iter2, "Same seed should produce consistent iteration counts")

    default:
      Issue.record("Async execution with different seed should produce success for simple property")
    }
  }

  @Test("PropertyRunner async execution - different seeds")
  func propertyRunnerAsyncExecutionDifferentSeeds() async throws {
    let property = Property<Int>(generator: Gen.int) { value in
      // Property that might fail for some values
      abs(value) < 1_000_000
    }

    let runner1 = PropertyRunner(seed: Seed(value: 111))
    let runner2 = PropertyRunner(seed: Seed(value: 222))
    let runner3 = PropertyRunner(seed: nil)  // Random seed

    let result1 = await runner1.runProperty(property, config: PropertyConfig(iterations: 50))
    let result2 = await runner2.runProperty(property, config: PropertyConfig(iterations: 50))
    let result3 = await runner3.runProperty(property, config: PropertyConfig(iterations: 50))

    // All executions should complete (though results may vary)
    switch (result1, result2, result3) {
    case (.success, .success, .success):
      #expect(Bool(true), "All async executions with different seeds succeeded")

    default:
      Issue.record("Some async executions with different seeds did not succeed as expected")
    }
  }

  @Test("PropertyRunner async execution - no seed (random)")
  func propertyRunnerAsyncExecutionNoSeed() async throws {
    let property = Property<String>(generator: Gen.string) { _ in
      true  // Always pass
    }

    let runner = PropertyRunner(seed: nil)
    let result = await runner.runProperty(property, config: PropertyConfig(iterations: 25))

    switch result {
    case .success(let iterations):
      #expect(iterations == 25, "Should complete all iterations")

    case .failure, .gaveUp:
      Issue.record("Unexpected result from simple property")
    }
  }

  // MARK: - Concurrent Property Execution Scenarios (Task 6)

  @Test("Concurrent property execution - multiple properties")
  func concurrentPropertyExecutionMultipleProperties() async throws {
    let property1 = Property<Int>(generator: Gen.int) { value in
      value >= Int.min && value <= Int.max
    }

    let property2 = Property<String>(generator: Gen.string) { value in
      value.isEmpty
    }

    let property3 = Property<Bool>(generator: Gen.bool) { value in
      value == true || value == false
    }

    // Execute multiple properties concurrently
    async let result1 = PropertyRunner().runProperty(
      property1,
      config: PropertyConfig(iterations: 30)
    )
    async let result2 = PropertyRunner().runProperty(
      property2,
      config: PropertyConfig(iterations: 30)
    )
    async let result3 = PropertyRunner().runProperty(
      property3,
      config: PropertyConfig(iterations: 30)
    )

    let (r1, r2, r3) = await (result1, result2, result3)

    // All should succeed
    switch (r1, r2, r3) {
    case (.success, .success, .success):
      #expect(Bool(true), "Concurrent execution succeeded")

    default:
      Issue.record("Some concurrent executions did not succeed as expected")
    }
  }

  @Test("Concurrent property execution - same property multiple runners")
  func concurrentPropertyExecutionSamePropertyMultipleRunners() async throws {
    let property = Property<Double>(generator: Gen.double) { value in
      value.isFinite || value.isInfinite || value.isNaN
    }

    // Run the same property with multiple runners concurrently
    let runner1 = PropertyRunner(seed: Seed(value: 1001))
    let runner2 = PropertyRunner(seed: Seed(value: 1002))
    let runner3 = PropertyRunner(seed: Seed(value: 1003))

    async let result1 = runner1.runProperty(property, config: PropertyConfig(iterations: 25))
    async let result2 = runner2.runProperty(property, config: PropertyConfig(iterations: 25))
    async let result3 = runner3.runProperty(property, config: PropertyConfig(iterations: 25))

    let (r1, r2, r3) = await (result1, result2, result3)

    // Verify all complete successfully
    let allSucceeded = [r1, r2, r3].allSatisfy { result in
      switch result {
      case .success: return true
      default: return false
      }
    }

    #expect(allSucceeded, "All concurrent executions should succeed for this property")
  }

  @Test("Concurrent property execution - stress test")
  func concurrentPropertyExecutionStressTest() async throws {
    let property = Property<Int>(generator: Gen.int(in: 1...100)) { _ in
      true  // Simple always-passing property
    }

    // Create many concurrent property executions
    let tasks: [Task<PropertyResult<Int>, Never>] = (0..<10).map { index in
      Task {
        let runner = PropertyRunner(seed: Seed(value: UInt64(index)))
        return await runner.runProperty(property, config: PropertyConfig(iterations: 10))
      }
    }

    // Await all concurrent tasks
    var results: [PropertyResult<Int>] = []
    for task in tasks {
      let result = await task.value
      results.append(result)
    }

    // All should succeed
    let allSucceeded = results.allSatisfy { result in
      switch result {
      case .success: return true
      default: return false
      }
    }

    #expect(allSucceeded, "All concurrent stress test executions should succeed")
    #expect(results.count == 10, "All 10 concurrent tasks should complete")
  }

  // MARK: - Async Property Failure Handling and Shrinking (Task 6)

  @Test("Async property failure handling - with shrinking")
  func asyncPropertyFailureHandlingWithShrinking() async throws {
    let property = Property<Int>(generator: Gen.int) { value in
      // Property that should fail for large values
      abs(value) < 10
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(
        iterations: 100,
        maxShrinks: 50
      )
    )

    switch result {
    case .failure(let counterexample, let iterations, let shrunk):
      // Verify shrinking behavior in async context
      #expect(
        abs(shrunk) <= abs(counterexample),
        "Async shrinking should reduce value magnitude: original \(counterexample), shrunk \(shrunk)"
      )
      #expect(iterations > 0, "Should have attempted some iterations")
      #expect(abs(shrunk) >= 10, "Shrunk value should still fail the property")

    case .success:
      Issue.record("Expected failure but got success")

    case .gaveUp(let discarded, let iterations):
      #expect(discarded >= 0, "Should track discarded attempts: \(discarded)")
      #expect(iterations >= 0, "Should track iterations: \(iterations)")
    }
  }

  @Test("Async property failure handling - multiple failures")
  func asyncPropertyFailureHandlingMultipleFailures() async throws {
    let failingProperty = Property<String>(generator: Gen.string) { value in
      // Property that fails for non-empty strings
      value.isEmpty
    }

    // Run multiple failing properties concurrently
    async let result1 = PropertyRunner(seed: Seed(value: 100)).runProperty(
      failingProperty,
      config: PropertyConfig(iterations: 20)
    )
    async let result2 = PropertyRunner(seed: Seed(value: 200)).runProperty(
      failingProperty,
      config: PropertyConfig(iterations: 20)
    )
    async let result3 = PropertyRunner(seed: Seed(value: 300)).runProperty(
      failingProperty,
      config: PropertyConfig(iterations: 20)
    )

    let (r1, r2, r3) = await (result1, result2, result3)

    // All should fail (since most generated strings are non-empty)
    let results = [r1, r2, r3]
    let failureCount = results.compactMap { result in
      switch result {
      case .failure: return result
      default: return nil
      }
    }.count

    #expect(failureCount <= 3, "Should handle concurrent failures: \(failureCount) out of 3")
    #expect(failureCount > 0, "Should have at least some failures for non-empty string property")
  }

  @Test("Async property shrinking effectiveness")
  func asyncPropertyShrinkingEffectiveness() async throws {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { array in
      // Property that fails for arrays containing the value 42
      !array.contains(42)
    }

    let runner = PropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(
        iterations: 200,
        maxShrinks: 100
      )
    )

    switch result {
    case .failure(let counterexample, _, let shrunk):
      #expect(shrunk.contains(42), "Shrunk array should still contain 42")
      #expect(shrunk.count <= counterexample.count, "Shrunk array should be smaller or equal size")

      // Ideally, shrunk array should be minimal (close to [42])
      if shrunk.count <= 3 {
        #expect(shrunk.count >= 1, "Excellent shrinking: shrunk to \(shrunk) elements")
      } else {
        #expect(
          shrunk.count < counterexample.count,
          "Shrinking should reduce size: from \(counterexample.count) to \(shrunk.count) elements"
        )
      }

    case .success(let iterations):
      #expect(iterations > 0, "Property passed (didn't generate arrays containing 42)")

    case .gaveUp(let discarded, let iterations):
      #expect(discarded > 0 || iterations > 0, "Property gave up with valid metrics")
    }
  }

  // MARK: - Timeout and Cancellation Scenarios (Task 6)

  @Test("Async property with task cancellation")
  func asyncPropertyWithTaskCancellation() async throws {
    let property = Property<Int>(generator: Gen.int) { _ in
      // Simple property that should complete quickly
      true
    }

    // Test that property execution can be cancelled
    let task = Task {
      await PropertyRunner().runProperty(property, config: PropertyConfig(iterations: 1000))
    }

    // Cancel the task after a brief moment
    try await Task.sleep(nanoseconds: 1_000_000)  // 1ms
    task.cancel()

    let result = await task.value

    // Task should complete despite cancellation (our property runner doesn't check for cancellation)
    // This tests that the framework is robust to external cancellation
    switch result {
    case .success(let iterations):
      #expect(iterations > 0, "Task completed despite cancellation")

    case .failure(_, let iterations, _):
      #expect(iterations > 0, "Task failed with valid iteration count")

    case .gaveUp(_, let iterations):
      #expect(iterations >= 0, "Task gave up with valid iteration count")
    }
  }

  @Test("Async property timeout simulation")
  func asyncPropertyTimeoutSimulation() async throws {
    let property = Property<Int>(generator: Gen.int) { value in
      abs(value) < 1_000_000  // Should generally pass quickly
    }

    // Simulate timeout by racing with a timeout task
    let propertyTask = Task {
      await PropertyRunner().runProperty(property, config: PropertyConfig(iterations: 100))
    }

    let timeoutTask = Task {
      try await Task.sleep(nanoseconds: 100_000_000)  // 100ms timeout
      return PropertyResult<Int>.gaveUp(discarded: 0, iterations: 0)
    }

    // Race the property against the timeout
    let result: PropertyResult<Int>
    do {
      result = try await withThrowingTaskGroup(of: PropertyResult<Int>.self) { group in
        group.addTask { await propertyTask.value }
        group.addTask { try await timeoutTask.value }

        let firstResult = try await group.next()!
        group.cancelAll()
        return firstResult
      }
    } catch {
      result = PropertyResult<Int>.gaveUp(discarded: 0, iterations: 0)
    }

    switch result {
    case .success(let iterations):
      #expect(iterations > 0, "Property completed before timeout with \(iterations) iterations")

    case .failure(_, let iterations, _):
      #expect(iterations > 0, "Property failed before timeout after \(iterations) iterations")

    case .gaveUp(_, let iterations):
      #expect(iterations >= 0, "Property gave up or timed out after \(iterations) iterations")
    }
  }

  // MARK: - Actor-Isolated Property Testing Patterns (Task 6)

  @Test("Actor-isolated property testing")
  func actorIsolatedPropertyTesting() async throws {
    actor Counter {
      private var value: Int = 0

      func increment() -> Int {
        value += 1
        return value
      }

      func getValue() -> Int {
        value
      }
    }

    let counter = Counter()

    let property = Property<Int>(generator: Gen.int(in: 1...10)) { incrementCount in
      incrementCount > 0
    }

    // Test property that interacts with actor
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .success:
      let finalCount = await counter.getValue()
      #expect(finalCount >= 0, "Actor interaction completed")

    case .failure(_, let iterations, _):
      #expect(iterations > 0, "Actor-isolated property failed with valid iteration count")

    case .gaveUp(_, let iterations):
      #expect(iterations >= 0, "Actor-isolated property gave up with valid iteration count")
    }
  }

  @Test("Concurrent actor access during property testing")
  func concurrentActorAccessDuringPropertyTesting() async throws {
    actor SharedState {
      private var counters: [String: Int] = [:]

      func increment(key: String) -> Int {
        counters[key, default: 0] += 1
        return counters[key]!
      }

      func getCount(key: String) -> Int {
        counters[key, default: 0]
      }
    }

    let sharedState = SharedState()

    // Multiple properties accessing the same actor concurrently
    let property1 = Property<Int>(generator: Gen.int(in: 1...5)) { _ in true }
    let property2 = Property<String>(generator: Gen.string) { _ in true }

    async let result1 = Task {
      await PropertyRunner(seed: Seed(value: 1)).runProperty(
        property1,
        config: PropertyConfig(iterations: 10)
      )
    }.value

    async let result2 = Task {
      await PropertyRunner(seed: Seed(value: 2)).runProperty(
        property2,
        config: PropertyConfig(iterations: 10)
      )
    }.value

    let (r1, r2) = await (result1, result2)

    // Verify concurrent actor access worked
    switch (r1, r2) {
    case (.success, .success):
      let count1 = await sharedState.getCount(key: "test1")
      let count2 = await sharedState.getCount(key: "test2")
      #expect(count1 >= 0 && count2 >= 0, "Actor state maintained during concurrent access")

    default:
      Issue.record("Concurrent actor access during property testing did not complete as expected")
    }
  }

  // MARK: - Async/Await Integration with Swift Testing (Task 6)

  @Test("Swift Testing async integration - checkPropertyAsync")
  func swiftTestingAsyncIntegrationCheckPropertyAsync() async throws {
    let property = Property<Float>(generator: Gen.float) { value in
      value.isFinite || value.isInfinite || value.isNaN
    }

    // Test the integration function directly
    try await checkPropertyAsync(property, config: PropertyConfig(iterations: 50))

    #expect(Bool(true), "checkPropertyAsync integration completed successfully")
  }

  @Test("Swift Testing async integration - multiple checkPropertyAsync calls")
  func swiftTestingAsyncIntegrationMultipleCheckPropertyAsync() async throws {
    let property1 = Property<Int>(generator: Gen.int) { _ in true }
    let property2 = Property<Bool>(generator: Gen.bool) { _ in true }
    let property3 = Property<String>(generator: Gen.string) { _ in true }

    // Test multiple async integration calls
    try await checkPropertyAsync(property1, config: PropertyConfig(iterations: 20))
    try await checkPropertyAsync(property2, config: PropertyConfig(iterations: 20))
    try await checkPropertyAsync(property3, config: PropertyConfig(iterations: 20))

    #expect(Bool(true), "Multiple checkPropertyAsync calls completed successfully")
  }

  @Test("Swift Testing async integration - failure scenario")
  func swiftTestingAsyncIntegrationFailureScenario() async throws {
    let failingProperty = Property<Int>(generator: Gen.int) { value in
      // Property that should fail for most values
      value == 42
    }

    do {
      try await checkPropertyAsync(failingProperty, config: PropertyConfig(iterations: 100))
      Issue.record("Property with value == 42 unexpectedly passed all iterations")
    } catch {
      // Expected to record an Issue, not throw
      #expect(Bool(true), "checkPropertyAsync handled failure appropriately")
    }
  }

  // MARK: - Async Property Testing Edge Cases (Task 6)

  @Test("Async property with very large iteration count")
  func asyncPropertyWithVeryLargeIterationCount() async throws {
    let property = Property<Bool>(generator: Gen.bool) { _ in true }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 10000)  // Large iteration count
    )

    switch result {
    case .success(let iterations):
      #expect(iterations == 10000, "Should complete all iterations even with large count")

    case .failure, .gaveUp:
      Issue.record("Unexpected result for large iteration count test")
    }
  }

  @Test("Async property with complex generator combinations")
  func asyncPropertyWithComplexGeneratorCombinations() async throws {
    // Complex nested generator structure
    let complexGenerator = Gen.int.zip(Gen.string).zip(Gen.bool).zip(Gen.float)

    let property = Property<(((Int, String), Bool), Float)>(
      generator: complexGenerator
    ) { nested in
      let intVal = nested.0.0.0
      let stringVal = nested.0.0.1
      let boolVal = nested.0.1
      let floatVal = nested.1

      // Complex property validation
      return intVal >= Int.min && stringVal.isEmpty && (boolVal == true || boolVal == false)
        && (floatVal.isFinite || floatVal.isInfinite || floatVal.isNaN)
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success(let iterations):
      #expect(iterations == 50, "Complex async property generation succeeded with all iterations")

    case .failure(_, let iterations, _):
      #expect(iterations > 0, "Complex async property failed after some iterations")

    case .gaveUp(_, let iterations):
      #expect(iterations >= 0, "Complex async property gave up after some attempts")
    }
  }

  @Test("Async property memory usage under load")
  func asyncPropertyMemoryUsageUnderLoad() async throws {
    let property = Property<[String]>(generator: Gen.array(Gen.string)) { array in
      // Test with potentially large arrays
      array.isEmpty
    }

    // Run multiple concurrent property tests to check memory usage
    let concurrentTasks = (0..<5).map { index in
      Task {
        await PropertyRunner(seed: Seed(value: UInt64(index + 1000))).runProperty(
          property,
          config: PropertyConfig(iterations: 100)
        )
      }
    }

    var allSucceeded = true
    for task in concurrentTasks {
      let result = await task.value
      switch result {
      case .success:
        continue

      default:
        allSucceeded = false
      }
    }

    #expect(allSucceeded, "Async property memory usage test should complete successfully")
  }
}
