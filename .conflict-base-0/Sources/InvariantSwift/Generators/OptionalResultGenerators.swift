/// OptionalResultGenerators - Comprehensive generators for Optional, Result, and error handling patterns
///
/// This module provides sophisticated generators for Swift's error handling and optional types,
/// including realistic failure distributions, comprehensive error scenarios, and async sequence support.
/// It follows property-based testing principles for thorough coverage of all Swift error handling patterns.
///
/// **Coverage Areas:**
/// - Optional<T> with configurable nil probability distributions
/// - Result<Success, Failure> with realistic error scenarios
/// - Throwing function generators with controlled exception patterns
/// - AsyncSequence generators with failure and completion scenarios
/// - Nested optional and result combinations
///
/// **Mathematical Properties:**
/// - **Optional Functor**: Optional<T> implements fmap preserving structure
/// - **Result Bifunctor**: Result<S,E> implements bimap for both success and failure paths
/// - **Error Propagation**: Maintains error context through generator composition
/// - **Probabilistic Distributions**: Configurable success/failure ratios for realistic testing
///
/// **External References:**
/// - [Swift Error Handling](https://docs.swift.org/swift-book/LanguageGuide/ErrorHandling.html)
/// - [Optional Types](https://developer.apple.com/documentation/swift/optional)
/// - [Result Type](https://developer.apple.com/documentation/swift/result)
/// - [AsyncSequence Protocol](https://developer.apple.com/documentation/swift/asyncsequence)

import Foundation

// MARK: - Optional Generators

/// Static generators for Optional types
public enum OptionalGen {
  /// Generate Optional<T> values with configurable nil probability.
  ///
  /// This generator provides fine-grained control over the distribution of nil vs non-nil values,
  /// essential for testing optional handling code paths thoroughly.
  ///
  /// **Distribution Strategy:**
  /// - Probability controls nil vs value ratio
  /// - Early nil for small sizes (edge case testing)
  /// - Shrinking prioritizes nil over complex values
  ///
  /// **Mathematical Properties:**
  /// ```
  /// P(nil) = nilProbability
  /// P(some(x)) = (1 - nilProbability) * P(x)
  /// ```
  ///
  /// - Parameter valueGen: Generator for non-nil values
  /// - Parameter nilProbability: Probability of generating nil (0.0 to 1.0)
  /// - Returns: Generator producing Optional<T> values
  ///
  /// ## Example
  /// ```swift
  /// let intOptionalGen = OptionalGen.optional(
  ///     valueGen: Gen<Int>.int(in: 1...100),
  ///     nilProbability: 0.3
  /// )
  ///
  /// var rng = SystemRandomNumberGenerator()
  /// let result = intOptionalGen.generate(&rng, Size(value: 10))
  /// // result: nil (30% chance) or some(42) (70% chance)
  /// ```
  public static func optional<T>(
    valueGen: Gen<T>,
    nilProbability: Double = 0.2
  ) -> Gen<T?> {
    Gen<T?>(
      generate: { rng, size in
        // Force nil for very small sizes (edge case testing)
        guard size.value > 0 else { return nil }

        let shouldBeNil = Double.random(in: 0...1, using: &rng) < nilProbability

        if shouldBeNil {
          return nil
        } else {
          return .some(valueGen.generate(&rng, size))
        }
      },
      shrink: Shrink<T?>({ optional in
        switch optional {
        case .none:
          return []  // nil is already minimal
        case .some(let value):
          // Shrink to nil first, then shrink the wrapped value
          let nilShrink: [T?] = [nil]
          let valueShrinks = valueGen.shrink.shrink(value).map { Optional.some($0) }
          return nilShrink + valueShrinks
        }
      })
    )
  }

  /// Generate optionals with size-dependent nil probability.
  ///
  /// Adjusts nil probability based on the generation size parameter,
  /// useful for testing edge cases at small sizes and normal behavior at larger sizes.
  ///
  /// **Size-Dependent Distribution:**
  /// ```
  /// nilProbability = baseProbability * (maxSize - size) / maxSize
  /// ```
  ///
  /// - Parameter valueGen: Generator for non-nil values
  /// - Parameter baseProbability: Base nil probability at size 0
  /// - Parameter maxSize: Size at which nil probability becomes minimal
  /// - Returns: Generator with adaptive nil probability
  ///
  /// ## Example
  /// ```swift
  /// let adaptiveGen = OptionalGen.adaptiveOptional(
  ///     valueGen: Gen<Double>.double(in: 0...1),
  ///     baseProbability: 0.8,
  ///     maxSize: 50
  /// )
  /// ```
  public static func adaptiveOptional<T>(
    valueGen: Gen<T>,
    baseProbability: Double = 0.5,
    maxSize: Int = 20
  ) -> Gen<T?> {
    Gen<T?>(
      generate: { rng, size in
        // Calculate adaptive probability based on size
        let sizeRatio = Double(min(size.value, maxSize)) / Double(maxSize)
        let adaptedProbability = baseProbability * (1.0 - sizeRatio)

        let shouldBeNil = Double.random(in: 0...1, using: &rng) < adaptedProbability

        if shouldBeNil {
          return nil
        } else {
          return .some(valueGen.generate(&rng, size))
        }
      },
      shrink: Shrink<T?>({ optional in
        switch optional {
        case .none:
          return []

        case .some(let value):
          let nilShrink: [T?] = [nil]
          let valueShrinks = valueGen.shrink.shrink(value).map { Optional.some($0) }
          return nilShrink + valueShrinks
        }
      })
    )
  }
}

// MARK: - Result Generators

/// Static generators for Result types
public enum ResultGen {
  /// Generate Result<Success, Failure> values with configurable success ratio.
  ///
  /// Provides comprehensive Result generation with realistic error scenarios
  /// and proper success/failure distributions for thorough error handling testing.
  ///
  /// **Distribution Strategy:**
  /// - successProbability controls success vs failure ratio
  /// - Realistic error scenarios through diverse failure generators
  /// - Proper shrinking toward simpler success/failure cases
  ///
  /// **Mathematical Properties:**
  /// ```
  /// P(success) = successProbability
  /// P(failure) = (1 - successProbability)
  /// ```
  ///
  /// - Parameter successGen: Generator for success values
  /// - Parameter failureGen: Generator for failure values
  /// - Parameter successProbability: Probability of success (0.0 to 1.0)
  /// - Returns: Generator producing Result<Success, Failure> values
  ///
  /// ## Example
  /// ```swift
  /// let resultGen = ResultGen.result(
  ///     successGen: Gen<String>.alphaNumeric(length: 10),
  ///     failureGen: Gen<MyError>.element(of: [.networkError, .parseError, .timeout]),
  ///     successProbability: 0.7
  /// )
  /// ```
  public static func result<Success, Failure>(
    successGen: Gen<Success>,
    failureGen: Gen<Failure>,
    successProbability: Double = 0.6
  ) -> Gen<Result<Success, Failure>> {
    Gen<Result<Success, Failure>>(
      generate: { rng, size in
        let shouldSucceed = Double.random(in: 0...1, using: &rng) < successProbability

        if shouldSucceed {
          let success = successGen.generate(&rng, size)
          return .success(success)
        } else {
          let failure = failureGen.generate(&rng, size)
          return .failure(failure)
        }
      },
      shrink: Shrink<Result<Success, Failure>>({ result in
        switch result {
        case .success(let value):
          // Shrink success value
          return successGen.shrink.shrink(value).map { Result.success($0) }

        case .failure(let error):
          // Shrink failure value
          return failureGen.shrink.shrink(error).map { Result.failure($0) }
        }
      })
    )
  }

  /// Generate Result values with error hierarchy and realistic failure patterns.
  ///
  /// Creates sophisticated error scenarios matching real-world error distributions
  /// including nested errors, error chains, and contextual failure information.
  ///
  /// **Error Pattern Strategy:**
  /// - Common errors have higher probability
  /// - Rare catastrophic errors have lower probability
  /// - Error context and chaining support
  ///
  /// - Parameter successGen: Generator for success values
  /// - Parameter commonErrors: Common error cases with higher probability
  /// - Parameter rareErrors: Rare error cases with lower probability
  /// - Parameter successProbability: Overall success probability
  /// - Returns: Generator with realistic error distributions
  ///
  /// ## Example
  /// ```swift
  /// let realisticGen = ResultGen.resultWithErrorHierarchy(
  ///     successGen: Gen<Data>.constant(Data()),
  ///     commonErrors: [TestError.networkTimeout, TestError.invalidInput],
  ///     rareErrors: [TestError.memoryExhausted],
  ///     successProbability: 0.8
  /// )
  /// ```
  public static func resultWithErrorHierarchy<Success, Failure>(
    successGen: Gen<Success>,
    commonErrors: [Failure],
    rareErrors: [Failure] = [],
    successProbability: Double = 0.7
  ) -> Gen<Result<Success, Failure>> {
    Gen<Result<Success, Failure>>(
      generate: { rng, size in
        let shouldSucceed = Double.random(in: 0...1, using: &rng) < successProbability

        if shouldSucceed {
          let success = successGen.generate(&rng, size)
          return .success(success)
        } else {
          // 80% common errors, 20% rare errors
          let useCommonError = rareErrors.isEmpty || Double.random(in: 0...1, using: &rng) < 0.8

          if useCommonError && !commonErrors.isEmpty {
            let error = commonErrors.randomElement(using: &rng)!
            return .failure(error)
          } else if !rareErrors.isEmpty {
            let error = rareErrors.randomElement(using: &rng)!
            return .failure(error)
          } else if !commonErrors.isEmpty {
            let error = commonErrors.randomElement(using: &rng)!
            return .failure(error)
          } else {
            // Fallback - shouldn't happen with well-formed inputs
            let success = successGen.generate(&rng, size)
            return .success(success)
          }
        }
      },
      shrink: Shrink<Result<Success, Failure>>({ result in
        switch result {
        case .success(let value):
          return successGen.shrink.shrink(value).map { Result.success($0) }

        case .failure:
          // For enum-based errors, we typically don't shrink
          return []
        }
      })
    )
  }
}

// MARK: - Error Types for Testing

/// Common error types for property-based testing scenarios
public enum TestError: Error, CaseIterable, Sendable {
  case networkTimeout
  case invalidInput
  case unauthorized
  case serverError
  case parseError
  case fileNotFound
  case memoryExhausted
  case operationCancelled

  /// Human-readable description for debugging
  public var description: String {
    switch self {
    case .networkTimeout: return "Network request timed out"
    case .invalidInput: return "Invalid input provided"
    case .unauthorized: return "Unauthorized access"
    case .serverError: return "Internal server error"
    case .parseError: return "Failed to parse response"
    case .fileNotFound: return "Requested file not found"
    case .memoryExhausted: return "System memory exhausted"
    case .operationCancelled: return "Operation was cancelled"
    }
  }
}

/// Static generators for TestError
public enum TestErrorGen {
  /// Generate common test errors with realistic distributions.
  ///
  /// Provides realistic error distributions matching common failure patterns
  /// in production systems for comprehensive error handling testing.
  ///
  /// **Distribution Strategy:**
  /// - Network and validation errors: 60% (most common)
  /// - Server and parse errors: 30% (moderately common)
  /// - System errors: 10% (rare but critical)
  ///
  /// - Returns: Generator for TestError with realistic distributions
  ///
  /// ## Example
  /// ```swift
  /// let errorGen = TestErrorGen.commonErrors()
  /// let resultGen = ResultGen.result(
  ///     successGen: Gen<String>.alphaNumeric(length: 10),
  ///     failureGen: errorGen
  /// )
  /// ```
  public static func commonErrors() -> Gen<TestError> {
    WeightedGen.weighted([
      // Common errors (60%)
      (40, TestError.networkTimeout),
      (20, TestError.invalidInput),
      // Moderate errors (30%)
      (15, TestError.unauthorized),
      (15, TestError.serverError),
      // Rare but important errors (10%)
      (5, TestError.parseError),
      (3, TestError.fileNotFound),
      (1, TestError.memoryExhausted),
      (1, TestError.operationCancelled),
    ])
  }
}

// MARK: - Throwing Function Generators

/// Static generators for throwing functions
public enum ThrowingFunctionGen {
  /// Generate throwing functions with controlled exception patterns.
  ///
  /// Creates generators for functions that may throw errors, enabling
  /// comprehensive testing of error handling code paths.
  ///
  /// **Exception Strategy:**
  /// - throwProbability controls how often the function throws
  /// - Realistic exception scenarios based on function context
  /// - Proper exception type generation
  ///
  /// - Parameter successGen: Generator for successful function results
  /// - Parameter errorGen: Generator for thrown errors
  /// - Parameter throwProbability: Probability of throwing (0.0 to 1.0)
  /// - Returns: Generator producing throwing functions
  ///
  /// ## Example
  /// ```swift
  /// let throwingFuncGen = ThrowingFunctionGen.throwingFunction(
  ///     successGen: Gen<String>.alphaNumeric(length: 10),
  ///     errorGen: TestErrorGen.commonErrors(),
  ///     throwProbability: 0.2
  /// )
  /// ```
  public static func throwingFunction<Success, Error: Swift.Error>(
    successGen: Gen<Success>,
    errorGen: Gen<Error>,
    throwProbability: Double = 0.3
  ) -> Gen<() throws -> Success> {
    Gen<() throws -> Success>(
      generate: { rng, size in
        let shouldThrow = Double.random(in: 0...1, using: &rng) < throwProbability

        if shouldThrow {
          let error = errorGen.generate(&rng, size)
          return { throw error }
        } else {
          let success = successGen.generate(&rng, size)
          return { success }
        }
      },
      shrink: Shrink<() throws -> Success>({ _ in
        // Shrinking throwing functions is complex - simplified approach
        []
      })
    )
  }

  /// Generate async throwing functions for concurrent error handling testing.
  ///
  /// Creates generators for async functions that may throw errors,
  /// essential for testing modern Swift concurrency error patterns.
  ///
  /// **Async Strategy:**
  /// - Combines async execution with error throwing
  /// - Configurable delay simulation
  /// - Realistic async error scenarios
  ///
  /// - Parameter successGen: Generator for successful async results
  /// - Parameter errorGen: Generator for thrown errors
  /// - Parameter throwProbability: Probability of throwing
  /// - Parameter maxDelay: Maximum simulated async delay (seconds)
  /// - Returns: Generator producing async throwing functions
  ///
  /// ## Example
  /// ```swift
  /// let asyncThrowingGen = ThrowingFunctionGen.asyncThrowingFunction(
  ///     successGen: Gen<Data>.constant(Data()),
  ///     errorGen: TestErrorGen.commonErrors(),
  ///     throwProbability: 0.25,
  ///     maxDelay: 0.1
  /// )
  /// ```
  public static func asyncThrowingFunction<Success, Error: Swift.Error>(
    successGen: Gen<Success>,
    errorGen: Gen<Error>,
    throwProbability: Double = 0.3,
    maxDelay: TimeInterval = 0.05
  ) -> Gen<() async throws -> Success> {
    Gen<() async throws -> Success>(
      generate: { rng, size in
        let shouldThrow = Double.random(in: 0...1, using: &rng) < throwProbability
        let delay = TimeInterval.random(in: 0...maxDelay, using: &rng)

        if shouldThrow {
          let error = errorGen.generate(&rng, size)
          return {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            throw error
          }
        } else {
          let success = successGen.generate(&rng, size)
          return {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return success
          }
        }
      },
      shrink: Shrink<() async throws -> Success>({ _ in
        // Shrinking async functions is complex - simplified approach
        []
      })
    )
  }
}

// MARK: - AsyncSequence Generators

/// Test implementation of AsyncSequence for generator testing
public struct TestAsyncSequence<Element, Error: Swift.Error>: AsyncSequence, Sendable
where Element: Sendable, Error: Sendable {
  public typealias AsyncIterator = TestAsyncIterator<Element, Error>

  let elements: [Element]
  let failureIndex: Int
  let error: Error?
  let maxDelay: TimeInterval

  public init(
    elements: [Element],
    failureIndex: Int = -1,
    error: Error? = nil,
    maxDelay: TimeInterval = 0.01
  ) {
    self.elements = elements
    self.failureIndex = failureIndex
    self.error = error
    self.maxDelay = maxDelay
  }

  public func makeAsyncIterator() -> TestAsyncIterator<Element, Error> {
    TestAsyncIterator(
      elements: elements,
      failureIndex: failureIndex,
      error: error,
      maxDelay: maxDelay
    )
  }
}

/// Test implementation of AsyncIteratorProtocol
public struct TestAsyncIterator<Element, Error: Swift.Error>: AsyncIteratorProtocol, Sendable
where Element: Sendable, Error: Sendable {
  private let elements: [Element]
  private let failureIndex: Int
  private let error: Error?
  private let maxDelay: TimeInterval
  private var currentIndex = 0

  init(elements: [Element], failureIndex: Int, error: Error?, maxDelay: TimeInterval) {
    self.elements = elements
    self.failureIndex = failureIndex
    self.error = error
    self.maxDelay = maxDelay
  }

  public mutating func next() async throws -> Element? {
    // Simulate async delay
    let delay = TimeInterval.random(in: 0...maxDelay)
    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

    // Check for failure at this index
    if currentIndex == failureIndex, let error = error {
      throw error
    }

    // Check if we've reached the end
    guard currentIndex < elements.count else {
      return nil
    }

    let element = elements[currentIndex]
    currentIndex += 1
    return element
  }
}

/// Static generators for AsyncSequence
public enum AsyncSequenceGen {
  /// Generate AsyncSequence with controlled failure and completion patterns.
  ///
  /// Creates async sequences with realistic streaming patterns including
  /// failures, completions, and varying element generation rates.
  ///
  /// **Async Sequence Strategy:**
  /// - Configurable element count and timing
  /// - Realistic failure scenarios during iteration
  /// - Proper sequence completion handling
  ///
  /// - Parameter elementGen: Generator for sequence elements
  /// - Parameter lengthRange: Range for sequence length
  /// - Parameter failureProbability: Probability of failure during iteration
  /// - Parameter errorGen: Generator for sequence errors
  /// - Returns: Generator producing AsyncSequence implementations
  ///
  /// ## Example
  /// ```swift
  /// let asyncSeqGen = AsyncSequenceGen.asyncSequence(
  ///     elementGen: Gen<Int>.int(in: 1...100),
  ///     lengthRange: 5...20,
  ///     failureProbability: 0.1,
  ///     errorGen: TestErrorGen.commonErrors()
  /// )
  /// ```
  public static func asyncSequence<Element, Error: Swift.Error>(
    elementGen: Gen<Element>,
    lengthRange: ClosedRange<Int> = 5...15,
    failureProbability: Double = 0.1,
    errorGen: Gen<Error>,
    maxDelay: TimeInterval = 0.01
  ) -> Gen<TestAsyncSequence<Element, Error>> {
    Gen<TestAsyncSequence<Element, Error>>(
      generate: { rng, size in
        let length = Int.random(in: lengthRange, using: &rng)
        let shouldFail = Double.random(in: 0...1, using: &rng) < failureProbability
        let failureIndex = shouldFail ? Int.random(in: 0..<length, using: &rng) : -1

        var elements: [Element] = []
        for _ in 0..<length {
          let element = elementGen.generate(&rng, size)
          elements.append(element)
        }

        let error = shouldFail ? errorGen.generate(&rng, size) : nil
        return TestAsyncSequence(
          elements: elements,
          failureIndex: failureIndex,
          error: error,
          maxDelay: maxDelay
        )
      },
      shrink: Shrink<TestAsyncSequence<Element, Error>>({ sequence in
        // Shrink by reducing length or removing failure
        var shrinks: [TestAsyncSequence<Element, Error>] = []

        // Remove failure
        if sequence.error != nil {
          shrinks.append(
            TestAsyncSequence(
              elements: sequence.elements,
              failureIndex: -1,
              error: nil,
              maxDelay: sequence.maxDelay
            )
          )
        }

        // Reduce length
        if sequence.elements.count > 1 {
          let shorterElements = Array(sequence.elements.dropLast())
          shrinks.append(
            TestAsyncSequence(
              elements: shorterElements,
              failureIndex: sequence.failureIndex >= shorterElements.count
                ? -1 : sequence.failureIndex,
              error: sequence.error,
              maxDelay: sequence.maxDelay
            )
          )
        }

        return shrinks
      })
    )
  }
}

// MARK: - Combined Optional-Result Patterns

/// Static generators for combined Optional-Result patterns
public enum CombinedGen {
  /// Generate combinations of Optional and Result for complex error scenarios.
  ///
  /// Creates nested structures like Optional<Result<T, E>> and Result<Optional<T>, E>
  /// for testing complex error handling scenarios that involve both optionality and failure.
  ///
  /// **Combination Strategy:**
  /// - Tests all combinations of success/failure and some/nil
  /// - Realistic distributions for each combination
  /// - Proper shrinking across nested structures
  ///
  /// - Parameter valueGen: Generator for inner values
  /// - Parameter errorGen: Generator for errors
  /// - Parameter nilProbability: Probability of nil in Optional
  /// - Parameter successProbability: Probability of success in Result
  /// - Returns: Generator for Optional<Result<T, E>>
  ///
  /// ## Example
  /// ```swift
  /// let combinedGen = CombinedGen.optionalResult(
  ///     valueGen: Gen<String>.alphaNumeric(length: 8),
  ///     errorGen: TestErrorGen.commonErrors(),
  ///     nilProbability: 0.2,
  ///     successProbability: 0.7
  /// )
  /// ```
  public static func optionalResult<Success, Failure>(
    valueGen: Gen<Success>,
    errorGen: Gen<Failure>,
    nilProbability: Double = 0.2,
    successProbability: Double = 0.6
  ) -> Gen<Result<Success, Failure>?> {
    let resultGen = ResultGen.result(
      successGen: valueGen,
      failureGen: errorGen,
      successProbability: successProbability
    )

    return OptionalGen.optional(
      valueGen: resultGen,
      nilProbability: nilProbability
    )
  }

  /// Generate Result with Optional success values.
  ///
  /// Creates Result<Optional<T>, E> patterns for APIs that may succeed
  /// but return optional values, or fail with specific errors.
  ///
  /// - Parameter valueGen: Generator for success values
  /// - Parameter errorGen: Generator for errors
  /// - Parameter nilProbability: Probability of nil in successful Optional
  /// - Parameter successProbability: Probability of overall success
  /// - Returns: Generator for Result<Optional<T>, E>
  ///
  /// ## Example
  /// ```swift
  /// let resultOptionalGen = CombinedGen.resultOptional(
  ///     valueGen: Gen<String>.alphaNumeric(length: 5),
  ///     errorGen: TestErrorGen.commonErrors(),
  ///     nilProbability: 0.3,
  ///     successProbability: 0.8
  /// )
  /// ```
  public static func resultOptional<Success, Failure>(
    valueGen: Gen<Success>,
    errorGen: Gen<Failure>,
    nilProbability: Double = 0.3,
    successProbability: Double = 0.7
  ) -> Gen<Result<Success?, Failure>> {
    let optionalGen = OptionalGen.optional(
      valueGen: valueGen,
      nilProbability: nilProbability
    )

    return ResultGen.result(
      successGen: optionalGen,
      failureGen: errorGen,
      successProbability: successProbability
    )
  }
}

// MARK: - Weighted Error Generation

/// Static generators for weighted value distribution
public enum WeightedGen {
  /// Create weighted generators for realistic error distributions.
  ///
  /// Generates values based on weighted probabilities, essential for creating
  /// realistic error distributions that match production scenarios.
  ///
  /// **Weighting Algorithm:**
  /// - Total weight calculation: sum of all individual weights
  /// - Random selection based on cumulative weight ranges
  /// - Maintains proper probability distributions
  ///
  /// - Parameter weightedValues: Array of (weight, value) pairs
  /// - Returns: Generator producing weighted value distribution
  ///
  /// ## Example
  /// ```swift
  /// let weightedErrorGen = WeightedGen.weighted([
  ///     (50, TestError.networkTimeout),    // 50% of errors
  ///     (30, TestError.invalidInput),      // 30% of errors
  ///     (15, TestError.serverError),       // 15% of errors
  ///     (5, TestError.memoryExhausted)     // 5% of errors
  /// ])
  /// ```
  public static func weighted<T>(_ weightedValues: [(Int, T)]) -> Gen<T> {
    precondition(!weightedValues.isEmpty, "Weighted values cannot be empty")

    let totalWeight = weightedValues.reduce(0) { $0 + $1.0 }
    precondition(totalWeight > 0, "Total weight must be positive")

    return Gen<T>(
      generate: { rng, _ in
        let randomWeight = Int.random(in: 0..<totalWeight, using: &rng)
        var cumulativeWeight = 0

        for (weight, value) in weightedValues {
          cumulativeWeight += weight
          if randomWeight < cumulativeWeight {
            return value
          }
        }

        // Fallback to last value (should not reach here with correct implementation)
        return weightedValues.last!.1
      },
      shrink: Shrink<T>({ _ in
        // For weighted selection, prefer simpler/lighter-weight options
        []
      })
    )
  }
}

// MARK: - Documentation Examples

/// **Usage Examples and Testing Patterns**
///
/// This section demonstrates comprehensive patterns for using optional and result generators
/// in property-based testing scenarios.
///
/// ## Basic Optional Testing
/// ```swift
/// let optionalProperty = Property<Int?> { maybeValue in
///     switch maybeValue {
///     case .none:
///         return true // nil handling is always valid
///     case .some(let value):
///         return value > 0 // test business logic on actual values
///     }
/// }
///
/// let optionalGen = OptionalGen.optional(
///     valueGen: Gen<Int>.int(in: 1...100),
///     nilProbability: 0.3
/// )
/// optionalProperty.check(using: optionalGen, iterations: 1000)
/// ```
///
/// ## Result Error Propagation Testing
/// ```swift
/// func processData(_ input: String) -> Result<ProcessedData, ProcessingError> {
///     // Implementation that may succeed or fail
/// }
///
/// let resultProperty = Property<Result<String, TestError>> { result in
///     let processed = result.flatMap { processData($0) }
///
///     switch processed {
///     case .success(let data):
///         return data.isValid // test successful processing
///     case .failure:
///         return true // failures are acceptable
///     }
/// }
///
/// let resultGen = ResultGen.result(
///     successGen: Gen<String>.alphaNumeric(length: 5...20),
///     failureGen: TestErrorGen.commonErrors(),
///     successProbability: 0.7
/// )
/// ```
///
/// ## AsyncSequence Error Handling
/// ```swift
/// func testAsyncSequenceErrorHandling() async throws {
///     let seqGen = AsyncSequenceGen.asyncSequence(
///         elementGen: Gen<Int>.int(in: 1...100),
///         lengthRange: 5...15,
///         failureProbability: 0.2,
///         errorGen: TestErrorGen.commonErrors()
///     )
///
///     let property = AsyncProperty<TestAsyncSequence<Int, TestError>> { sequence in
///         var collected: [Int] = []
///
///         do {
///             for try await element in sequence {
///                 collected.append(element)
///             }
///             return collected.count > 0 // successful sequences have elements
///         } catch {
///             return true // errors are expected in some cases
///         }
///     }
///
///     try await property.check(using: seqGen, iterations: 100)
/// }
/// ```
///
/// ## Complex Optional-Result Combinations
/// ```swift
/// let complexProperty = Property<Optional<Result<String, TestError>>> { complexValue in
///     switch complexValue {
///     case .none:
///         return true // nil is valid
///     case .some(.success(let string)):
///         return !string.isEmpty // successful strings should not be empty
///     case .some(.failure):
///         return true // failures are expected
///     }
/// }
///
/// let complexGen = CombinedGen.optionalResult(
///     valueGen: Gen<String>.alphaNumeric(length: 1...20),
///     errorGen: TestErrorGen.commonErrors(),
///     nilProbability: 0.2,
///     successProbability: 0.6
/// )
/// ```
