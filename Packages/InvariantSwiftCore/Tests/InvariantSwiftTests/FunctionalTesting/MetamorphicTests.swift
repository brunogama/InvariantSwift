/// MetamorphicTests - Comprehensive tests for metamorphic testing engine
///
/// Verifies MetamorphicRelation, MetamorphicProperty, RelationCatalog,
/// MetamorphicTestRunner, and MetamorphicDiscoveryEngine.

import Testing
import Foundation
@testable import InvariantSwift
@testable import InvariantSwiftAdvanced

@Suite("Metamorphic Testing")
struct MetamorphicTests {

  // MARK: - MetamorphicRelation Tests

  @Test("MetamorphicRelation correctly detects relation violations")
  func testRelationViolationDetection() async {
    // Create a relation that checks if sorting is idempotent
    let idempotentRelation = MetamorphicRelation<[Int], [Int]>(
      name: "sorting_idempotence",
      inputTransform: { $0.sorted() },
      outputRelation: { original, transformed in original == transformed },
      description: "Sorting sorted array should not change it"
    )

    // Test: sorting function should satisfy idempotence
    let sortFunction: @Sendable ([Int]) -> [Int] = { $0.sorted() }

    let inputs = [[3, 1, 2], [5, 4, 3, 2, 1], [1], [], [1, 1, 1]]
    let result = idempotentRelation.checkWithConfidence(sortFunction, inputs: inputs)

    #expect(result.isValid, "Sorting should be idempotent")
    #expect(result.successRate == 1.0, "All tests should pass")
    #expect(result.violations.isEmpty, "No violations expected")
  }

  @Test("MetamorphicRelation detects failing relations")
  func testRelationFailureDetection() async {
    // Create a relation that will fail - expects doubling to preserve equality
    let failingRelation = MetamorphicRelation<Int, Int>(
      name: "bad_relation",
      inputTransform: { $0 * 2 },
      outputRelation: { original, transformed in original == transformed },
      description: "This should fail"
    )

    let identityFunction: @Sendable (Int) -> Int = { $0 }
    let inputs = [1, 2, 3, 4, 5]
    let result = failingRelation.checkWithConfidence(identityFunction, inputs: inputs)

    #expect(!result.isValid, "Relation should fail")
    #expect(result.successRate < 1.0, "Not all tests should pass")
    #expect(!result.violations.isEmpty, "Should have violations")
  }

  // MARK: - RelationCategory Tests

  @Test("RelationCategory has all expected categories")
  func testRelationCategories() {
    let allCategories = RelationCategory.allCases

    #expect(allCategories.contains(.algebraic))
    #expect(allCategories.contains(.permutation))
    #expect(allCategories.contains(.addition))
    #expect(allCategories.contains(.scaling))
    #expect(allCategories.contains(.equivalence))
    #expect(allCategories.contains(.monotonic))
    #expect(allCategories.contains(.invariant))
    #expect(allCategories.contains(.transformation))
  }

  // MARK: - RelationCatalog Tests

  @Test("Sorting relations from catalog work correctly")
  func testSortingRelationsCatalog() async {
    let relations: [MetamorphicRelation<[Int], [Int]>] = RelationCatalog.sortingRelations()

    #expect(relations.count >= 3, "Should have at least 3 sorting relations")

    let sortFunction: @Sendable ([Int]) -> [Int] = { $0.sorted() }
    let inputs = [[3, 1, 2], [5, 4], [1], []]

    for relation in relations {
      let result = relation.checkWithConfidence(sortFunction, inputs: inputs)
      #expect(result.isValid, "Sorting relation '\(relation.name)' should hold")
    }
  }

  @Test("Arithmetic relations from catalog work correctly")
  func testArithmeticRelationsCatalog() async {
    let relations = RelationCatalog.arithmeticRelations()

    #expect(!relations.isEmpty, "Should have arithmetic relations")

    // Test addition commutativity
    let addFunction: @Sendable ((Double, Double)) -> Double = { $0.0 + $0.1 }
    let inputs: [(Double, Double)] = [(1.0, 2.0), (3.0, 4.0), (0.0, 0.0)]

    if let commutativeRelation = relations.first(where: { $0.name == "addition_commutativity" }) {
      let result = commutativeRelation.checkWithConfidence(addFunction, inputs: inputs)
      #expect(result.isValid, "Addition should be commutative")
    }
  }

  @Test("String relations from catalog work correctly")
  func testStringRelationsCatalog() async {
    let relations = RelationCatalog.stringRelations()

    #expect(!relations.isEmpty, "Should have string relations")

    let lengthFunction: @Sendable (String) -> Int = { $0.count }
    let inputs = ["hello", "world", "", "test"]

    // At least one relation should work with length function
    var anyValid = false
    for relation in relations {
      let result = relation.checkWithConfidence(lengthFunction, inputs: inputs)
      if result.isValid {
        anyValid = true
      }
    }

    #expect(anyValid, "At least one string relation should hold")
  }

  // MARK: - MetamorphicProperty Tests

  @Test("MetamorphicProperty tests all relations")
  func testMetamorphicPropertyExecution() async {
    let relations: [MetamorphicRelation<[Int], [Int]>] = [
      MetamorphicRelation(
        name: "size_preservation",
        inputTransform: { $0 },
        outputRelation: { original, transformed in original.count == transformed.count },
        description: "Sorting preserves size"
      ),
      MetamorphicRelation(
        name: "idempotence",
        inputTransform: { $0.sorted() },
        outputRelation: { original, transformed in original == transformed },
        description: "Sorting is idempotent"
      ),
    ]

    let property = MetamorphicProperty(
      generator: Gen<[Int]>.array(Gen<Int>.int),
      function: { (arr: [Int]) -> [Int] in arr.sorted() },
      relations: relations
    )

    let results = await property.test(iterations: 20)

    #expect(results.count == 2, "Should test both relations")
    for result in results {
      #expect(result.isValid, "Relation '\(result.relation)' should hold")
    }
  }

  // MARK: - MetamorphicTestRunner Tests

  @Test("MetamorphicTestRunner produces correct results")
  func testMetamorphicTestRunner() async {
    let runner = MetamorphicTestRunner()

    let property = MetamorphicProperty(
      generator: Gen<[Int]>.array(Gen<Int>.int),
      function: { (arr: [Int]) -> [Int] in arr.sorted() },
      relations: RelationCatalog.sortingRelations()
    )

    let result = await runner.run(property, iterations: 10)

    #expect(result.isSuccess, "All sorting relations should hold")
    #expect(result.totalRelations >= 3, "Should test all catalog relations")
    #expect(result.validRelations == result.totalRelations, "All should be valid")
    #expect(result.iterations == 10, "Should use specified iterations")
  }

  @Test("MetamorphicTestRunner summary is readable")
  func testMetamorphicTestRunnerSummary() async {
    let runner = MetamorphicTestRunner()

    let property = MetamorphicProperty(
      generator: Gen.pure([1, 2, 3]),
      function: { (arr: [Int]) -> [Int] in arr.sorted() },
      relations: RelationCatalog.sortingRelations()
    )

    let result = await runner.run(property, iterations: 5)
    let summary = result.summary()

    #expect(summary.contains("Metamorphic Testing Summary"))
    #expect(summary.contains("Total Relations:"))
    #expect(summary.contains("Overall Success:"))
  }

  // MARK: - Gen Extension Tests

  @Test("Generator metamorphic extension creates valid property")
  func testGenMetamorphicExtension() async {
    let relations: [MetamorphicRelation<Int, Int>] = [
      MetamorphicRelation(
        name: "double_monotonic",
        inputTransform: { $0 + 1 },
        outputRelation: { original, transformed in transformed >= original },
        description: "Doubling is monotonic with increment"
      )
    ]

    let property = Gen<Int>.int.metamorphic(
      function: { $0 * 2 },
      relations: relations
    )

    let results = await property.test(iterations: 10)
    #expect(!results.isEmpty, "Should produce results")
  }

  // MARK: - MetamorphicDiscoveryEngine Tests

  @Test("Discovery engine can analyze functions")
  func testMetamorphicDiscoveryEngine() async {
    let engine = MetamorphicDiscoveryEngine()

    let identityFunction: @Sendable (Int) -> Int = { $0 }

    let discovered = await engine.discover(
      function: identityFunction,
      generator: Gen<Int>.int,
      sampleSize: 50,
      confidenceThreshold: 0.8
    )

    // Identity function should have idempotence discovered
    #expect(!discovered.isEmpty, "Should discover at least one relation")
  }

  // MARK: - Edge Cases

  @Test("Empty input handling")
  func testEmptyInputHandling() async {
    let relation = MetamorphicRelation<[Int], [Int]>(
      name: "empty_test",
      inputTransform: { $0 },
      outputRelation: { _, _ in true },
      description: "Empty test"
    )

    let sortFunction: @Sendable ([Int]) -> [Int] = { $0.sorted() }
    let emptyInputs: [[Int]] = []

    // Should not crash with empty inputs
    let result = relation.checkWithConfidence(sortFunction, inputs: emptyInputs)
    #expect(result.totalTests == 0, "Should handle empty inputs")
  }

  @Test("Single element handling")
  func testSingleElementHandling() async {
    let relation = MetamorphicRelation<[Int], [Int]>(
      name: "single_test",
      inputTransform: { $0 },
      outputRelation: { original, transformed in original == transformed },
      description: "Single element test"
    )

    let sortFunction: @Sendable ([Int]) -> [Int] = { $0.sorted() }
    let singleInputs: [[Int]] = [[42]]

    let result = relation.checkWithConfidence(sortFunction, inputs: singleInputs)
    #expect(result.isValid, "Single element should work")
  }

  // MARK: - RelationViolation Tests

  @Test("RelationViolation captures all details")
  func testRelationViolationDetails() {
    let violation = RelationViolation(
      relation: "test_relation",
      originalInput: [1, 2, 3],
      transformedInput: [3, 2, 1],
      originalOutput: [1, 2, 3],
      transformedOutput: [1, 2, 3]
    )

    #expect(violation.relation == "test_relation")
    #expect(violation.originalInput == [1, 2, 3])
    #expect(violation.transformedInput == [3, 2, 1])
  }

  @Test("AnyRelationViolation type erasure works")
  func testAnyRelationViolation() {
    let violation = RelationViolation(
      relation: "test",
      originalInput: 42,
      transformedInput: 84,
      originalOutput: "hello",
      transformedOutput: "world"
    )

    let anyViolation = AnyRelationViolation(violation)

    #expect(anyViolation.relation == "test")
    #expect(anyViolation.originalInputDescription == "42")
    #expect(anyViolation.transformedInputDescription == "84")
  }
}
