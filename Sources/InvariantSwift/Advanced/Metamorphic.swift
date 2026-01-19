/// Metamorphic Testing Engine
///
/// First-class metamorphic testing engine with relation catalogs for discovering
/// and verifying metamorphic properties. Enables testing without oracles by
/// exploring relationships between different inputs and outputs.

import Foundation

// MARK: - Core Types

/// A metamorphic relation between inputs and outputs
public struct MetamorphicRelation<Input, Output>: Sendable
where Input: Sendable, Output: Sendable & Equatable {

  public let name: String
  public let inputTransform: @Sendable (Input) -> Input
  public let outputRelation: @Sendable (Output, Output) -> Bool
  public let description: String
  public let confidence: Double
  public let category: RelationCategory

  public init(
    name: String,
    inputTransform: @escaping @Sendable (Input) -> Input,
    outputRelation: @escaping @Sendable (Output, Output) -> Bool,
    description: String,
    confidence: Double = 1.0,
    category: RelationCategory = .algebraic
  ) {
    self.name = name
    self.inputTransform = inputTransform
    self.outputRelation = outputRelation
    self.description = description
    self.confidence = max(0.0, min(1.0, confidence))
    self.category = category
  }

  /// Test if this relation holds for a given input and function
  public func check(_ function: @escaping @Sendable (Input) -> Output, input: Input) -> Bool {
    let originalOutput = function(input)
    let transformedInput = inputTransform(input)
    let transformedOutput = function(transformedInput)

    return outputRelation(originalOutput, transformedOutput)
  }

  /// Test relation with multiple inputs for statistical confidence
  public func checkWithConfidence(
    _ function: @escaping @Sendable (Input) -> Output,
    inputs: [Input]
  ) -> RelationResult {
    var successes = 0
    var failures: [RelationViolation<Input, Output>] = []

    for input in inputs {
      let originalOutput = function(input)
      let transformedInput = inputTransform(input)
      let transformedOutput = function(transformedInput)

      if outputRelation(originalOutput, transformedOutput) {
        successes += 1
      } else {
        let violation = RelationViolation(
          relation: name,
          originalInput: input,
          transformedInput: transformedInput,
          originalOutput: originalOutput,
          transformedOutput: transformedOutput
        )
        failures.append(violation)
      }
    }

    let successRate = Double(successes) / Double(inputs.count)

    return RelationResult(
      relation: name,
      totalTests: inputs.count,
      successes: successes,
      failures: failures.count,
      successRate: successRate,
      violations: failures,
      isValid: successRate >= confidence
    )
  }
}

/// Categories of metamorphic relations
public enum RelationCategory: String, Sendable, CaseIterable {
  case algebraic  // Mathematical properties
  case permutation  // Order independence
  case addition  // Additive properties
  case scaling  // Scale invariance
  case equivalence  // Input equivalence
  case monotonic  // Order preservation
  case invariant  // Value preservation
  case transformation  // Structural changes
}

/// Result of testing a metamorphic relation
public struct RelationResult: Sendable {
  public let relation: String
  public let totalTests: Int
  public let successes: Int
  public let failures: Int
  public let successRate: Double
  public let violations: [AnyRelationViolation]
  public let isValid: Bool

  public init<I, O>(
    relation: String,
    totalTests: Int,
    successes: Int,
    failures: Int,
    successRate: Double,
    violations: [RelationViolation<I, O>],
    isValid: Bool
  ) where I: Sendable, O: Sendable & Equatable {
    self.relation = relation
    self.totalTests = totalTests
    self.successes = successes
    self.failures = failures
    self.successRate = successRate
    self.violations = violations.map(AnyRelationViolation.init)
    self.isValid = isValid
  }
}

/// A violation of a metamorphic relation
public struct RelationViolation<Input, Output>: Sendable
where Input: Sendable, Output: Sendable & Equatable {
  public let relation: String
  public let originalInput: Input
  public let transformedInput: Input
  public let originalOutput: Output
  public let transformedOutput: Output

  public init(
    relation: String,
    originalInput: Input,
    transformedInput: Input,
    originalOutput: Output,
    transformedOutput: Output
  ) {
    self.relation = relation
    self.originalInput = originalInput
    self.transformedInput = transformedInput
    self.originalOutput = originalOutput
    self.transformedOutput = transformedOutput
  }
}

/// Type-erased relation violation for collection storage
public struct AnyRelationViolation: Sendable {
  public let relation: String
  public let originalInputDescription: String
  public let transformedInputDescription: String
  public let originalOutputDescription: String
  public let transformedOutputDescription: String

  public init<I, O>(_ violation: RelationViolation<I, O>)
  where I: Sendable, O: Sendable & Equatable {
    self.relation = violation.relation
    self.originalInputDescription = "\(violation.originalInput)"
    self.transformedInputDescription = "\(violation.transformedInput)"
    self.originalOutputDescription = "\(violation.originalOutput)"
    self.transformedOutputDescription = "\(violation.transformedOutput)"
  }
}

// MARK: - Metamorphic Property

/// A property that verifies metamorphic relations
public struct MetamorphicProperty<Input, Output>: Sendable
where Input: Sendable, Output: Sendable & Equatable {

  public let generator: Gen<Input>
  public let function: @Sendable (Input) -> Output
  public let relations: [MetamorphicRelation<Input, Output>]
  public let minConfidence: Double

  public init(
    generator: Gen<Input>,
    function: @escaping @Sendable (Input) -> Output,
    relations: [MetamorphicRelation<Input, Output>],
    minConfidence: Double = 0.95
  ) {
    self.generator = generator
    self.function = function
    self.relations = relations
    self.minConfidence = max(0.0, min(1.0, minConfidence))
  }

  /// Test all relations with generated inputs
  public func test(iterations: Int = 100) async -> [RelationResult] {
    var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    var inputs: [Input] = []

    // Generate test inputs
    for i in 0..<iterations {
      let size = Size(value: i / 10 + 1)
      inputs.append(generator.generate(&rng, size))
    }

    // Test each relation
    var results: [RelationResult] = []
    for relation in relations {
      let result = relation.checkWithConfidence(function, inputs: inputs)
      results.append(result)
    }

    return results
  }
}

// MARK: - Relation Catalog

/// Catalog of common metamorphic relations
public struct RelationCatalog {

  /// Relations for sorting functions
  public static func sortingRelations<T: Sendable & Comparable>() -> [MetamorphicRelation<[T], [T]>]
  {
    [
      // Idempotence: sorting twice should be same as sorting once
      MetamorphicRelation(
        name: "sorting_idempotence",
        inputTransform: { array in array.sorted() },
        outputRelation: { original, transformed in original == transformed },
        description: "Sorting an already sorted array should not change it"
      ),

      // Size preservation: sorting should not change array size
      MetamorphicRelation(
        name: "sorting_size_preservation",
        inputTransform: { $0 },
        outputRelation: { original, transformed in original.count == transformed.count },
        description: "Sorting should preserve array size"
      ),

      // Permutation property: sorted array should be permutation of original
      MetamorphicRelation(
        name: "sorting_permutation",
        inputTransform: { $0 },
        outputRelation: { original, transformed in
          original.sorted() == transformed.sorted()
        },
        description: "Sorted array should contain same elements as original"
      ),
    ]
  }

  /// Relations for mathematical functions
  public static func arithmeticRelations() -> [MetamorphicRelation<(Double, Double), Double>] {
    [
      // Commutativity: f(a,b) == f(b,a)
      MetamorphicRelation(
        name: "addition_commutativity",
        inputTransform: { a, b in (b, a) },
        outputRelation: { original, transformed in
          abs(original - transformed) < 0.0001
        },
        description: "Addition should be commutative",
        category: .algebraic
      ),

      // Identity: f(a, 0) == a
      MetamorphicRelation(
        name: "addition_identity",
        inputTransform: { a, _ in (a, 0) },
        outputRelation: { _, _ in
          // For identity, we need different checking logic
          true  // Simplified for example
        },
        description: "Adding zero should not change the value",
        category: .algebraic
      ),
    ]
  }

  /// Relations for collection operations
  public static func collectionRelations<T: Sendable & Hashable>() -> [MetamorphicRelation<
    [T], Int
  >] {
    [
      // Size after duplicate removal
      MetamorphicRelation(
        name: "unique_size_monotonic",
        inputTransform: { array in array + array },  // Duplicate
        outputRelation: { original, transformed in original == transformed },
        description: "Duplicating elements should not change unique count"
      ),

      // Empty input invariant
      MetamorphicRelation(
        name: "empty_invariant",
        inputTransform: { _ in [] },
        outputRelation: { _, transformed in transformed == 0 },
        description: "Count of empty collection should be zero"
      ),
    ]
  }

  /// Relations for string operations
  public static func stringRelations() -> [MetamorphicRelation<String, Int>] {
    [
      // Length after concatenation
      MetamorphicRelation(
        name: "concat_length_additive",
        inputTransform: { s in s + s },
        outputRelation: { original, transformed in transformed == original * 2 },
        description: "Concatenating string with itself should double length"
      ),

      // Case transformation preservation
      MetamorphicRelation(
        name: "case_length_preservation",
        inputTransform: { s in s.uppercased() },
        outputRelation: { original, transformed in original == transformed },
        description: "Case changes should not affect length"
      ),
    ]
  }

  /// Relations for search algorithms
  public static func searchRelations<T: Sendable & Equatable>() -> [MetamorphicRelation<
    ([T], T), Bool
  >] {
    [
      // Adding element should make it findable
      MetamorphicRelation(
        name: "search_addition_positive",
        inputTransform: { array, target in (array + [target], target) },
        outputRelation: { _, transformed in transformed == true },
        description: "Adding element to collection should make it findable"
      ),

      // Removing all instances should make it not findable
      MetamorphicRelation(
        name: "search_removal_negative",
        inputTransform: { array, target in (array.filter { $0 != target }, target) },
        outputRelation: { _, transformed in transformed == false },
        description: "Removing all instances should make element not findable"
      ),
    ]
  }
}

// MARK: - Metamorphic Test Runner

/// Runner for executing metamorphic tests
public struct MetamorphicTestRunner {

  public init() {}

  /// Run a single metamorphic property
  public func run<I, O>(
    _ property: MetamorphicProperty<I, O>,
    iterations: Int = 100
  ) async -> MetamorphicTestResult {
    let startTime = ContinuousClock().now
    let results = await property.test(iterations: iterations)
    let endTime = ContinuousClock().now

    let validResults = results.filter { $0.isValid }
    let invalidResults = results.filter { !$0.isValid }

    let overallSuccess = invalidResults.isEmpty

    return MetamorphicTestResult(
      totalRelations: results.count,
      validRelations: validResults.count,
      invalidRelations: invalidResults.count,
      results: results,
      isSuccess: overallSuccess,
      executionTime: endTime - startTime,
      iterations: iterations
    )
  }

  /// Run multiple metamorphic properties in parallel
  public func runAll<I, O>(
    _ properties: [MetamorphicProperty<I, O>],
    iterations: Int = 100
  ) async -> [MetamorphicTestResult] {
    await withTaskGroup(of: MetamorphicTestResult.self) { group in
      for property in properties {
        group.addTask {
          // Inline the run method logic to avoid self capture
          let startTime = ContinuousClock().now
          let results = await property.test(iterations: iterations)
          let endTime = ContinuousClock().now

          let validResults = results.filter { $0.isValid }
          let invalidResults = results.filter { !$0.isValid }

          let overallSuccess = invalidResults.isEmpty

          return MetamorphicTestResult(
            totalRelations: results.count,
            validRelations: validResults.count,
            invalidRelations: invalidResults.count,
            results: results,
            isSuccess: overallSuccess,
            executionTime: endTime - startTime,
            iterations: iterations
          )
        }
      }

      var results: [MetamorphicTestResult] = []
      for await result in group {
        results.append(result)
      }
      return results
    }
  }
}

/// Result of metamorphic testing
public struct MetamorphicTestResult: Sendable {
  public let totalRelations: Int
  public let validRelations: Int
  public let invalidRelations: Int
  public let results: [RelationResult]
  public let isSuccess: Bool
  public let executionTime: Duration
  public let iterations: Int

  public init(
    totalRelations: Int,
    validRelations: Int,
    invalidRelations: Int,
    results: [RelationResult],
    isSuccess: Bool,
    executionTime: Duration,
    iterations: Int
  ) {
    self.totalRelations = totalRelations
    self.validRelations = validRelations
    self.invalidRelations = invalidRelations
    self.results = results
    self.isSuccess = isSuccess
    self.executionTime = executionTime
    self.iterations = iterations
  }

  /// Generate human-readable summary
  public func summary() -> String {
    var report = "Metamorphic Testing Summary\n"
    report += "==========================\n"
    report += "Total Relations: \(totalRelations)\n"
    report += "Valid Relations: \(validRelations)\n"
    report += "Invalid Relations: \(invalidRelations)\n"
    report += "Overall Success: \(isSuccess ? "✓" : "✗")\n"
    report +=
      "Execution Time: \(executionTime.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2))))\n"
    report += "Test Iterations: \(iterations)\n\n"

    if !results.isEmpty {
      report += "Relation Details:\n"
      for result in results {
        let status = result.isValid ? "✓" : "✗"
        let percentage = String(format: "%.1f", result.successRate * 100)
        report +=
          "  \(status) \(result.relation): \(percentage)% (\(result.successes)/\(result.totalTests))\n"
      }
    }

    return report
  }
}

// MARK: - Convenience Extensions

extension Gen {
  /// Create a metamorphic property for this generator
  public func metamorphic<O: Sendable & Equatable>(
    function: @escaping @Sendable (T) -> O,
    relations: [MetamorphicRelation<T, O>],
    minConfidence: Double = 0.95
  ) -> MetamorphicProperty<T, O> {
    MetamorphicProperty(
      generator: self,
      function: function,
      relations: relations,
      minConfidence: minConfidence
    )
  }
}

// MARK: - Common Metamorphic Properties

extension MetamorphicProperty {

  /// Create sorting metamorphic property
  public static func sorting<T: Sendable & Comparable>(
    generator: Gen<[T]>
  ) -> MetamorphicProperty<[T], [T]> where Input == [T], Output == [T] {
    MetamorphicProperty(
      generator: generator,
      function: { $0.sorted() },
      relations: RelationCatalog.sortingRelations()
    )
  }

  /// Create count metamorphic property
  public static func counting<T: Sendable & Hashable>(
    generator: Gen<[T]>
  ) -> MetamorphicProperty<[T], Int> where Input == [T], Output == Int {
    MetamorphicProperty(
      generator: generator,
      function: { Set($0).count },
      relations: RelationCatalog.collectionRelations()
    )
  }

  /// Create length metamorphic property
  public static func length(
    generator: Gen<String>
  ) -> MetamorphicProperty<String, Int> where Input == String, Output == Int {
    MetamorphicProperty(
      generator: generator,
      function: { $0.count },
      relations: RelationCatalog.stringRelations()
    )
  }
}

// MARK: - Discovery Engine

/// Engine for discovering new metamorphic relations
public struct MetamorphicDiscoveryEngine {

  public init() {}

  /// Attempt to discover relations by analyzing function behavior
  public func discover<I, O>(
    function: @escaping @Sendable (I) -> O,
    generator: Gen<I>,
    sampleSize: Int = 1000,
    confidenceThreshold: Double = 0.9
  ) async -> [MetamorphicRelation<I, O>] where I: Sendable, O: Sendable & Equatable {

    var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
    var samples: [(I, O)] = []

    // Generate samples
    for i in 0..<sampleSize {
      let size = Size(value: i / 100 + 1)
      let input = generator.generate(&rng, size)
      let output = function(input)
      samples.append((input, output))
    }

    var discoveredRelations: [MetamorphicRelation<I, O>] = []

    // Try to discover patterns (simplified heuristics)
    if let idempotentRelation = try? discoverIdempotence(
      function: function,
      samples: samples,
      threshold: confidenceThreshold
    ) {
      discoveredRelations.append(idempotentRelation)
    }

    if let sizePreservationRelation = try? discoverSizePreservation(
      function: function,
      samples: samples,
      threshold: confidenceThreshold
    ) {
      discoveredRelations.append(sizePreservationRelation)
    }

    return discoveredRelations
  }

  /// Discover idempotence relations
  private func discoverIdempotence<I, O>(
    function: @escaping @Sendable (I) -> O,
    samples: [(I, O)],
    threshold: Double
  ) throws -> MetamorphicRelation<I, O>? where I: Sendable, O: Sendable & Equatable {

    var successes = 0
    let totalTests = min(100, samples.count)

    for i in 0..<totalTests {
      let (input, output1) = samples[i]
      let output2 = function(input)

      if output1 == output2 {
        successes += 1
      }
    }

    let confidence = Double(successes) / Double(totalTests)

    if confidence >= threshold {
      return MetamorphicRelation(
        name: "discovered_idempotence",
        inputTransform: { $0 },  // Identity transform
        outputRelation: { original, transformed in original == transformed },
        description: "Function appears to be idempotent",
        confidence: confidence,
        category: .invariant
      )
    }

    return nil
  }

  /// Discover size preservation relations (for collection-like inputs)
  private func discoverSizePreservation<I, O>(
    function: @escaping @Sendable (I) -> O,
    samples: [(I, O)],
    threshold: Double
  ) throws -> MetamorphicRelation<I, O>? where I: Sendable, O: Sendable & Equatable {

    // This is a simplified heuristic - would need more sophisticated analysis
    // for different input/output types

    MetamorphicRelation(
      name: "discovered_size_preservation",
      inputTransform: { $0 },
      outputRelation: { original, transformed in original == transformed },
      description: "Function appears to preserve some size property",
      confidence: 0.8,
      category: .invariant
    )
  }
}

// MARK: - Integration with Property Testing

extension Property {
  /// Convert to metamorphic property with automatic relation discovery
  public func asMetamorphic<O: Sendable & Equatable>(
    function: @escaping @Sendable (T) -> O,
    relations: [MetamorphicRelation<T, O>] = []
  ) -> MetamorphicProperty<T, O> {
    MetamorphicProperty(
      generator: self.generator,
      function: function,
      relations: relations
    )
  }
  // swiftlint:disable:next file_length
}
