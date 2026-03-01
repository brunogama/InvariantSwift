import Foundation

/// A testable proposition over generated values of type T.
///
/// `Property<T>` combines a generator with a predicate to form a property:
/// "For all generated values of type T, this predicate holds."
///
/// The property is the fundamental abstraction in property-based testing. Rather than
/// writing individual test cases, you specify a property that should hold universally.
/// The property tester generates many examples and checks the property against each.
///
/// Key concepts:
/// - **Generator**: Produces random test values via `Gen<T>`
/// - **Predicate**: Boolean function checking the property on each value
/// - **Assumption** (optional): Filter for valid test cases (e.g., "only test non-empty arrays")
/// - **Shrinking**: Automatically minimizes counterexamples for easier debugging
///
/// When a property fails, the test framework reports:
/// - The failing input (counterexample)
/// - The minimal failing input (shrunk) for easier debugging
/// - The number of iterations before failure
///
/// A property succeeds if the predicate returns true for all generated test cases.
/// It fails if the predicate returns false on any generated value.
///
/// - Example:
///   ```swift
///   // Property: "Arrays reverse twice give back the original"
///   let arrayGen = Gen.array(Gen<Int> { rng, _ in Int.random(in: 0..<100, using: &rng) })
///
///   let reverseProperty = Property(generator: arrayGen) { array in
///       array.reversed().reversed() == array
///   }
///
///   // Property with assumption: "Non-empty arrays"
///   let headProperty = Property(
///       generator: arrayGen,
///       assumption: { !$0.isEmpty },
///       predicate: { array in
///           array.first == array.reversed().last
///       }
///   )
///   ```
///
/// - See Also: ``PropertyRunner``, ``PropertyResult``, ``Gen``
public struct Property<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  ///
  /// Assumptions are used to filter the input space. If a generated value
  /// doesn't satisfy the assumption, it is discarded and another value is tried.
  public let assumption: @Sendable (T) -> Bool
  /// The predicate that must hold true for all valid test cases.
  public let predicate: @Sendable (T) -> Bool

  /// Initialize a property with a generator and predicate.
  ///
  /// - Parameters:
  ///   - generator: Values to test
  ///   - assumption: Filter for valid values (default: all valid)
  ///   - predicate: Condition that must hold true
  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Throwing Property

/// A property that can throw errors during execution.
///
/// If the predicate throws, it's considered a failure unless it's a known
/// discard signal.
public struct ThrowingProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool
  /// The predicate that must hold true (or not throw).
  public let predicate: @Sendable (T) throws -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) throws -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Evaluating Property

/// A property that returns explicit evaluation results.
///
/// Useful for complex properties that need to signal success, failure,
/// or discard with detailed reasons.
public struct EvaluatingProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The predicate returning explicit evaluation outcomes.
  public let evaluate: @Sendable (T) -> PropertyEvaluation

  public init(
    generator: Gen<T>,
    evaluate: @escaping @Sendable (T) -> PropertyEvaluation
  ) {
    self.generator = generator
    self.evaluate = evaluate
  }
}

// MARK: - Async Property

/// A property with an async predicate.
///
/// Supports properties that require asynchronous operations during evaluation,
/// such as network calls, database queries, or concurrent computations.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct AsyncProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool
  /// The async predicate that must hold true for all valid test cases.
  public let predicate: @Sendable (T) async -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) async -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Async Throwing Property

/// A property with an async predicate that can throw errors.
///
/// Combines async operations with error handling. Thrown errors are captured
/// and reported as failures with `.threwError` reason.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct AsyncThrowingProperty<T: Sendable>: @unchecked Sendable {
  /// The generator producing test values for this property.
  public let generator: Gen<T>
  /// The assumption (precondition) that filters valid test cases.
  public let assumption: @Sendable (T) -> Bool
  /// The async predicate that must hold true (or not throw).
  public let predicate: @Sendable (T) async throws -> Bool

  public init(
    generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool = { _ in true },
    predicate: @escaping @Sendable (T) async throws -> Bool
  ) {
    self.generator = generator
    self.assumption = assumption
    self.predicate = predicate
  }
}

// MARK: - Convenience Extensions

extension Property {
  /// Create a property that checks a boolean condition
  public static func check(
    _ generator: Gen<T>,
    _ condition: @escaping @Sendable (T) -> Bool
  ) -> Property<T> {
    Property(generator: generator, predicate: condition)
  }

  /// Create a property with an implication (assumption -> conclusion)
  public static func implies(
    _ generator: Gen<T>,
    assumption: @escaping @Sendable (T) -> Bool,
    conclusion: @escaping @Sendable (T) -> Bool
  ) -> Property<T> {
    Property(
      generator: generator,
      predicate: { value in
        !assumption(value) || conclusion(value)
      }
    )
  }
}

// MARK: - Property Combinators

extension Property {
  /// Combine two properties with logical AND
  public func and<U>(_ other: Property<U>) -> Property<(T, U)> {
    Property<(T, U)>(
      generator: self.generator.zip(other.generator),
      predicate: { pair in
        self.predicate(pair.0) && other.predicate(pair.1)
      }
    )
  }

  /// Combine two properties with logical OR
  public func or<U>(_ other: Property<U>) -> Property<(T, U)> {
    Property<(T, U)>(
      generator: self.generator.zip(other.generator),
      predicate: { pair in
        self.predicate(pair.0) || other.predicate(pair.1)
      }
    )
  }

  /// Negate this property (logical NOT).
  ///
  /// Creates a new property that passes when this property fails, and fails when
  /// this property passes. Useful for testing boolean algebra laws like:
  /// - `p ∧ ¬p = ⊥` (contradiction)
  /// - `p ∨ ¬p = ⊤` (tautology)
  ///
  /// - Returns: A property with inverted predicate semantics
  ///
  /// - Example:
  ///   ```swift
  ///   let positive = Property(generator: Gen.int) { $0 > 0 }
  ///   let nonPositive = positive.negation()  // $0 <= 0
  ///   ```
  public func negation() -> Property<T> {
    Property(generator: self.generator, predicate: { value in !self.predicate(value) })
  }

  /// A property that always passes (logical TRUE / tautology).
  ///
  /// Creates a property that passes for any generated value. Useful as an identity
  /// element for testing boolean algebra laws like `p ∧ ⊤ = p`.
  ///
  /// - Parameter generator: The generator to use for test values
  /// - Returns: A property that always returns true
  ///
  /// - Example:
  ///   ```swift
  ///   let tautology = Property<Int>.tautology(Gen.int)
  ///   let result = runPropertySynchronously(tautology)
  ///   // Always .success
  ///   ```
  public static func tautology(_ generator: Gen<T>) -> Property<T> {
    Property(generator: generator, predicate: { _ in true })
  }

  /// A property that always fails (logical FALSE / contradiction).
  ///
  /// Creates a property that fails for any generated value. Useful as an identity
  /// element for testing boolean algebra laws like `p ∨ ⊥ = p`.
  ///
  /// - Parameter generator: The generator to use for test values
  /// - Returns: A property that always returns false
  ///
  /// - Example:
  ///   ```swift
  ///   let contradiction = Property<Int>.contradiction(Gen.int)
  ///   let result = runPropertySynchronously(contradiction)
  ///   // Always .failure
  ///   ```
  public static func contradiction(_ generator: Gen<T>) -> Property<T> {
    Property(generator: generator, predicate: { _ in false })
  }

  // MARK: - Transformation Combinators

  // swiftlint:disable:next orphaned_doc_comment
  /// Transform the predicate while keeping the same generator.
  ///
  /// Useful for wrapping or modifying the predicate logic without changing generation.
  ///
  /// - Parameter transform: Function that takes the current predicate and returns a new one
  /// - Returns: Property with transformed predicate
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 > 0 }
  ///   let wrapped = prop.mapPredicate { predicate in
  ///       { value in
  // swiftlint:disable:next no_print
  ///           print("Testing: \(value)")
  ///           return predicate(value)
  ///       }
  ///   }
  ///   ```
  public func mapPredicate(
    _ transform: @escaping (@escaping @Sendable (T) -> Bool) -> @Sendable (T) -> Bool
  ) -> Property<T> {
    Property(generator: self.generator, predicate: transform(self.predicate))
  }

  /// Transform the generator while keeping the same predicate.
  ///
  /// Useful for modifying how values are generated without changing the property assertion.
  ///
  /// - Parameter transform: Function that takes the current generator and returns a new one
  /// - Returns: Property with transformed generator
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 >= 0 }
  ///   let nonNegative = prop.mapGenerator { gen in
  ///       gen.map { abs($0) }
  ///   }
  ///   ```
  public func mapGenerator(_ transform: @escaping (Gen<T>) -> Gen<T>) -> Property<T> {
    Property(generator: transform(self.generator), predicate: self.predicate)
  }

  /// Filter generated values using an assumption (alias for suchThat).
  ///
  /// Values that don't satisfy the filter condition are discarded. Be careful not to
  /// filter out too many values, as this can cause the property test to give up.
  ///
  /// - Parameter condition: Predicate that generated values must satisfy
  /// - Returns: Property that only tests values satisfying the condition
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 * $0 >= 0 }
  ///   let positiveOnly = prop.filter { $0 > 0 }
  ///   ```
  public func filter(_ condition: @escaping @Sendable (T) -> Bool) -> Property<T> {
    // Combine the filter condition with the existing assumption
    let combinedAssumption: @Sendable (T) -> Bool = { value in
      self.assumption(value) && condition(value)
    }
    return Property(
      generator: self.generator,
      assumption: combinedAssumption,
      predicate: self.predicate
    )
  }

  /// Attach a descriptive label to this property for better failure messages.
  ///
  /// Labels appear in test output and help identify which property failed when
  /// running multiple properties.
  ///
  /// - Parameter name: Descriptive label for the property
  /// - Returns: A labeled property wrapper
  ///
  /// - Example:
  ///   ```swift
  ///   let prop = Property(generator: Gen.int) { $0 >= 0 }
  ///       .label("non-negative integers")
  ///   ```
  public func label(_ name: String) -> LabeledProperty<T> {
    LabeledProperty(property: self, label: name)
  }
}

// MARK: - Labeled Property

/// A property with an attached descriptive label for failure reporting.
///
/// Use the `label(_:)` method on `Property` to create a `LabeledProperty`.
/// The label appears in test output and helps identify which property failed.
public struct LabeledProperty<T: Sendable>: @unchecked Sendable {
  /// The underlying property.
  public let property: Property<T>

  /// Descriptive label for test output.
  public let label: String

  /// Initialize a labeled property.
  public init(property: Property<T>, label: String) {
    self.property = property
    self.label = label
  }
}

// MARK: - Synchronous Property Testing Helper

/// Helper function to run a property test synchronously from synchronous contexts.
///
/// **Important**: This function is provided for compatibility with synchronous test contexts
/// like performance benchmarks. For new code, prefer async/await patterns with `PropertyRunner`.
///
/// This creates a new runner, seeds it, and executes the property test synchronously.
/// The result is guaranteed to be deterministic if a seed is provided.
///
/// - Parameters:
///   - property: The property to test
///   - config: Configuration for the test execution
///
/// - Returns: The result of running the property (success, failure, or gave up)
///
/// - Example:
///   ```swift
///   let property = Property(generator: Gen.int) { $0 >= 0 }
///   let result = runPropertySynchronously(property, config: PropertyConfig(iterations: 100))
///   ```
///
/// - See Also: ``PropertyRunner.runProperty(_:config:)`` for async variant
public func runPropertySynchronously<T>(
  _ property: Property<T>,
  config: PropertyConfig = .default
) -> PropertyResult<T> {
  let actualSeed = config.seed ?? Seed.random
  var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: actualSeed)

  var discarded = 0
  var successfulIterations = 0

  while successfulIterations < config.iterations {
    let size = Size(value: min(successfulIterations, 100))
    // Generate tree for proper shrinking (essential for flatMap)
    let tree = property.generator.generateTree(&rng, size)
    let testCase = tree.value

    // Check assumption first - discarded values never reach the predicate
    if !property.assumption(testCase) {
      discarded += 1
      if discarded > config.maxDiscarded {
        return .gaveUp(discarded: discarded, iterations: successfulIterations)
      }
      continue
    }

    // Assumption passed, check the predicate
    if !property.predicate(testCase) {
      // Use tree-based shrinking for proper dependent generator support
      let shrunkCase = shrinkFailureWithTreeSynchronously(
        tree,
        property: property,
        maxShrinks: config.maxShrinks
      )
      return .failure(
        counterexample: testCase,
        iterations: successfulIterations + 1,
        shrunk: shrunkCase,
        reason: .predicateFailed,
        seed: actualSeed
      )
    }

    successfulIterations += 1
  }

  return .success(iterations: successfulIterations)
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public func runPropertyAsync<T: Sendable>(
  _ property: Property<T>,
  config: PropertyConfig = .default
) async -> PropertyResult<T> {
  let runner = PropertyRunner(seed: config.seed)
  return await runner.runProperty(property, config: config)
}

private func shrinkFailureWithTreeSynchronously<T>(
  _ tree: ShrinkTree<T>,
  property: Property<T>,
  maxShrinks: Int
) -> T {
  // Filter tree to respect assumptions
  let filteredTree = tree.filter { property.assumption($0) }

  // BFS search for minimal counterexample that still fails the predicate
  let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
    !property.predicate(candidate)
  }

  return minimal ?? tree.value
}

private func shrinkFailureSynchronously<T>(
  _ failingCase: T,
  property: Property<T>,
  maxShrinks: Int
) -> T {
  // Build shrink tree from the failing case
  let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)

  // Use tree-based shrinking
  return shrinkFailureWithTreeSynchronously(tree, property: property, maxShrinks: maxShrinks)
}

/// Run a throwing property test synchronously.
///
/// Similar to `runPropertySynchronously`, but supports predicates that may throw.
/// Thrown errors are caught and classified as `.threwError` failures.
///
/// - Parameters:
///   - property: The throwing property to test
///   - config: Configuration for test execution
///
/// - Returns: The result of running the property
public func runThrowingPropertySynchronously<T>(
  _ property: ThrowingProperty<T>,
  config: PropertyConfig = .default
) -> PropertyResult<T> {
  let actualSeed = config.seed ?? Seed.random
  var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: actualSeed)

  var discarded = 0
  var successfulIterations = 0

  while successfulIterations < config.iterations {
    let size = Size(value: min(successfulIterations, 100))
    let testCase = property.generator.generate(&rng, size)

    // Check assumption first
    if !property.assumption(testCase) {
      discarded += 1
      if discarded > config.maxDiscarded {
        return .gaveUp(discarded: discarded, iterations: successfulIterations)
      }
      continue
    }

    // Assumption passed, check the predicate
    do {
      if try !property.predicate(testCase) {
        // Predicate returned false
        let shrunkCase = shrinkThrowingFailureSynchronously(
          testCase,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: actualSeed
        )
      }
    } catch {
      // Predicate threw an error
      let errorDescription = String(describing: error)
      let shrunkCase = shrinkThrowingFailureSynchronously(
        testCase,
        property: property,
        maxShrinks: config.maxShrinks
      )
      return .failure(
        counterexample: testCase,
        iterations: successfulIterations + 1,
        shrunk: shrunkCase,
        reason: .threwError(errorDescription),
        seed: actualSeed
      )
    }

    successfulIterations += 1
  }

  return .success(iterations: successfulIterations)
}

private func shrinkThrowingFailureSynchronously<T>(
  _ failingCase: T,
  property: ThrowingProperty<T>,
  maxShrinks: Int
) -> T {
  // Build shrink tree from the failing case
  let tree = ShrinkTree.from(failingCase, shrink: property.generator.shrink)

  // Filter tree to respect assumptions
  let filteredTree = tree.filter { property.assumption($0) }

  // BFS search for minimal counterexample that still fails (returns false or throws)
  let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
    do {
      return try !property.predicate(candidate)
    } catch {
      return true  // Throws = still fails
    }
  }

  return minimal ?? failingCase
}

/// Result of running a predicate with timeout.
private enum PredicateTimeoutResult {
  case success(Bool)
  case timedOut
}

/// Internal result type for predicate/timeout race.
private enum PredicateRaceResult {
  case predicateFinished(Bool)
  case timeoutReached
}
