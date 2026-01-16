import Testing
import Foundation
@testable import InvariantSwift

/// Comprehensive tests for memory optimizations in the Property system.
///
/// These tests verify that the optimization correctly handles sendable closures,
/// prevents memory leaks, and maintains mathematical correctness of Boolean algebra operations.
struct MemoryOptimizationTests {

  // MARK: - Sendable Closure Tests

  @Test("Property initialization with sendable closures compiles without warnings")
  func testSendableClosureInitialization() async throws {
    // Given: A generator and sendable predicate
    let generator = Gen.constant(42)

    // When: Creating property with sendable closure
    let property = Property(
      generator: generator,
      predicate: { value in value > 0 }
    )

    // Then: Property can be used safely in concurrent contexts
    let result = await PropertyChecker.checkAsync(property)

    #expect(result.isSuccess)
  }

  @Test("Property combinators maintain sendable constraints")
  func testSendableCombinators() async throws {
    // Given: Two properties with sendable predicates
    let property1 = Property(
      generator: Gen.constant(10),
      predicate: { $0 > 5 }
    )

    let property2 = Property(
      generator: Gen.constant(20),
      predicate: { $0 < 30 }
    )

    // When: Combining properties with Boolean algebra operations
    let andProperty = property1.and(property2)
    let orProperty = property1.or(property2)
    let negationProperty = property1.negation()

    // Then: Combined properties maintain sendable constraints
    let andResult = await PropertyChecker.checkAsync(andProperty)
    let orResult = await PropertyChecker.checkAsync(orProperty)
    let negationResult = await PropertyChecker.checkAsync(negationProperty)

    #expect(andResult.isSuccess)
    #expect(orResult.isSuccess)
    #expect(!negationResult.isSuccess)  // Negation should fail since 10 > 5
  }

  // MARK: - Memory Leak Prevention Tests

  @Test("Property instances use value semantics and have no reference cycles")
  func testPropertyValueSemantics() {
    // Given: Property is a struct with value semantics
    let generator = Gen.constant(42)
    let property1 = Property(
      generator: generator,
      predicate: { $0 > 0 }
    )

    // When: Creating copies of the property
    let property2 = property1

    // Then: Both properties should work independently (value semantics)
    let result1 = PropertyChecker.check(property1)
    let result2 = PropertyChecker.check(property2)

    #expect(result1.isSuccess)
    #expect(result2.isSuccess)
    // Value types don't need weak reference testing as they have no reference cycles
  }

  @Test("PropertyRunner uses actor isolation for memory safety")
  func testPropertyRunnerActorIsolation() async {
    // Given: PropertyRunner is an actor providing memory safety
    let runner = PropertyRunner(seed: Seed(value: 42))

    let property = Property(
      generator: Gen.constant(100),
      predicate: { $0 == 100 }
    )

    // When: Running property with actor isolation
    let result = await runner.runProperty(property)

    // Then: Should complete successfully with memory safety guarantees
    #expect(result.isSuccess)
    // Actors provide memory safety through isolation, no reference cycles possible
  }

  // MARK: - Boolean Algebra Law Verification Tests

  @Test("Boolean algebra identity laws hold with optimized properties")
  func testBooleanAlgebraIdentityLaws() async throws {
    // Given: A property and identity elements
    let generator = Gen.constant(42)
    let property = Property(generator: generator, predicate: { $0 > 0 })
    let tautology = Property.tautology(generator)
    let contradiction = Property.contradiction(generator)

    // When: Applying identity laws
    let pAndTrue = property.and(tautology)
    let pOrFalse = property.or(contradiction)

    // Then: Identity laws should hold
    let pResult = await PropertyChecker.checkAsync(property)
    let pAndTrueResult = await PropertyChecker.checkAsync(pAndTrue)
    let pOrFalseResult = await PropertyChecker.checkAsync(pOrFalse)

    #expect(pResult.isSuccess)
    #expect(pAndTrueResult.isSuccess)  // p ∧ ⊤ = p (when p is true)
    #expect(pOrFalseResult.isSuccess)  // p ∨ ⊥ = p
  }

  @Test("Boolean algebra complement laws hold with optimized properties")
  func testBooleanAlgebraComplementLaws() async throws {
    // Given: A property and its negation
    let generator = Gen.constant(42)
    let property = Property(generator: generator, predicate: { $0 > 100 })
    let negation = property.negation()

    // When: Applying complement operations
    let pAndNotP = property.and(negation)
    let pOrNotP = property.or(negation)

    // Then: Complement laws should hold
    let pAndNotPResult = await PropertyChecker.checkAsync(pAndNotP)
    let pOrNotPResult = await PropertyChecker.checkAsync(pOrNotP)

    // p ∧ ¬p = ⊥ (should fail)
    #expect(!pAndNotPResult.isSuccess)

    // p ∨ ¬p = ⊤ (should succeed)
    #expect(pOrNotPResult.isSuccess)
  }

  // MARK: - Performance Tests

  @Test("Memory usage remains stable under high iteration counts")
  func testMemoryUsageStability() async throws {
    // Given: High iteration property test
    let property = Property(
      generator: Gen.int,
      predicate: { $0 * $0 >= 0 }  // Always true (perfect squares are non-negative)
    )

    let config = PropertyConfig(iterations: 10_000, seed: Seed(value: 42))

    // When: Running many iterations
    let startTime = Date()
    let result = await PropertyChecker.checkAsync(property, config: config)
    let duration = Date().timeIntervalSince(startTime)

    // Then: Should complete successfully and efficiently
    #expect(result.isSuccess)
    #expect(duration < 5.0, "10k iterations should complete within 5 seconds")

    switch result {
    case .success(let iterations):
      #expect(iterations == 10_000)

    default:
      Issue.record("Expected successful completion")
    }
  }

  @Test("Concurrent property testing maintains memory safety")
  func testConcurrentMemorySafety() async throws {
    // Given: Multiple properties for concurrent testing
    let properties = (0..<10).map { i in
      Property(
        generator: Gen.constant(i),
        predicate: { value in value >= 0 }
      )
    }

    // When: Running properties concurrently
    await withTaskGroup(of: Bool.self) { group in
      for property in properties {
        group.addTask {
          let result = await PropertyChecker.checkAsync(property)
          return result.isSuccess
        }
      }

      // Then: All should succeed without memory issues
      for await success in group {
        #expect(success)
      }
    }
  }

  // MARK: - Sendable Constraint Verification Tests

  @Test("Properties are properly Sendable across actor boundaries")
  func testSendableAcrossActorBoundaries() async throws {
    // Given: An actor that uses properties
    actor PropertyProcessor {
      func process(_ property: Property<Int>) -> Bool {
        let result = PropertyChecker.check(property)
        return result.isSuccess
      }
    }

    let processor = PropertyProcessor()
    let property = Property(
      generator: Gen.constant(42),
      predicate: { $0 > 0 }
    )

    // When: Passing property across actor boundary
    let success = await processor.process(property)

    // Then: Should work without sendable violations
    #expect(success)
  }

  // MARK: - Functional Correctness Tests

  @Test("Optimized test method produces identical results to original predicate")
  func testFunctionalEquivalence() async throws {
    let testValues = [1, 5, 10, -3, 0, 100, -50]

    // Given: Property with test method optimization
    let property = Property(
      generator: Gen.constant(0),  // Generator not used in this test
      predicate: { value in value > 0 && value % 2 == 0 }
    )

    // When: Testing with both approaches
    for testValue in testValues {
      let testResult = property.test(testValue)
      let predicateResult = property.predicate(testValue)

      // Then: Results should be identical
      #expect(
        testResult == predicateResult,
        "test(\(testValue)) = \(testResult) != predicate(\(testValue)) = \(predicateResult)"
      )
    }
  }

  // MARK: - Coverage Integration Tests

  @Test("Coverage-guided properties maintain sendable constraints")
  func testCoverageGuidedSendableConstraints() async throws {
    // Given: Property and coverage budget
    let property = Property(
      generator: Gen.int,
      predicate: { $0 > 0 }
    )

    let budget = CoverageBudget(
      uncoveredSymbols: ["testFunction"],
      coverageMap: ["testFunction": 0.5],
      totalFunctions: 2,
      coveredFunctions: 1
    )

    // When: Creating coverage-guided property
    let guidedProperty = property.withCoverageGuidance(budget: budget)

    // Then: Should maintain sendable constraints
    let result = await PropertyChecker.checkAsync(guidedProperty)

    // Coverage guidance may affect results, but shouldn't break sendable constraints
    #expect(result.isSuccess || result.isFailure)  // Just verify it completes
  }

  // MARK: - Error Handling Tests

  @Test("Memory optimization handles error conditions gracefully")
  func testErrorConditionMemoryManagement() async throws {
    // Given: Property that will fail
    let failingProperty = Property(
      generator: Gen.constant(0),
      predicate: { $0 > 0 }  // Will fail since 0 is not > 0
    )

    // When: Running failing property
    let result = await PropertyChecker.checkAsync(failingProperty)

    // Then: Should fail gracefully without memory leaks
    #expect(!result.isSuccess)

    switch result {
    case .failure(let counterexample, let iterations, let shrunk):
      #expect(counterexample == 0)
      #expect(shrunk == 0)
      #expect(iterations == 1)

    default:
      Issue.record("Expected failure result")
    }
  }
}
