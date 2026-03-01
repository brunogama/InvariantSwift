import Foundation

// swiftlint:disable:next orphaned_doc_comment
/// Actor for thread-safe property test execution with shrinking support.
///
/// `PropertyRunner` is the main entry point for executing property-based tests.
/// It coordinates:
/// - Generating test values via the property's generator
/// - Checking the property's predicate on each value
/// - Shrinking when failures occur to find minimal counterexamples
///
/// Actor isolation ensures thread-safe execution. Property tests can run
/// concurrently on different actors without data races.
///
/// **Workflow**:
/// 1. Initialize runner with optional seed
/// 2. Create a property with generator and predicate
/// 3. Call `runProperty` with the property and configuration
/// 4. Interpret the `PropertyResult` (success, failure, or gaveUp)
///
/// **Seeding**:
/// - With seed: All test runs are identical (deterministic)
/// - Without seed: Uses system randomness (different each run)
///
/// Deterministic execution is useful for:
/// - Reproducing test failures for debugging
/// - Regression testing with specific seeds
/// - Distributed testing by seed ranges
///
/// - Example:
///   ```swift
///   let runner = PropertyRunner()
///   let property = Property(generator: Gen.pure(5)) { n in n > 0 }
///
///   let result = await runner.runProperty(property)
///   switch result {
///   case .success(let iterations):
// swiftlint:disable:next no_print
///       print("✓ Passed \(iterations) tests")
///   case .failure(let counterexample, let iterations, let shrunk, _, _):
// swiftlint:disable:next no_print
///       print("✗ Failed: \(shrunk)")
///   case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///       print("? Gave up after \(discarded) discards")
///   }
///   ```
///
/// - See Also: ``Property``, ``PropertyConfig``, ``PropertyResult``
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor PropertyRunner {
  var rng: any RandomNumberGenerator
  /// Internal seed for extensions to access during property execution.
  let seed: Seed

  /// Initializes a property runner with optional seed.
  ///
  /// Creates a runner for executing properties. The optional seed determines
  /// whether test execution is deterministic (with seed) or random (without).
  ///
  /// - Parameters:
  ///   - seed: Optional seed for deterministic execution. If nil, uses system randomness.
  ///
  /// - Example:
  ///   ```swift
  ///   let deterministicRunner = PropertyRunner(seed: Seed(value: 42))
  ///   let randomRunner = PropertyRunner()
  ///   ```
  public init(seed: Seed? = nil) {
    let actualSeed = seed ?? Seed.random
    self.seed = actualSeed
    self.rng = SeedBasedRandomNumberGenerator(seed: actualSeed)
  }

  /// Executes a property test with given configuration.
  ///
  /// Runs the property on generated test cases and reports the outcome:
  /// - `.success` if the property holds for all iterations
  /// - `.failure` with minimal counterexample if property fails
  /// - `.gaveUp` if too many generated values violate assumptions
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Configuration controlling iterations and shrinking. Default: `PropertyConfig.default`
  ///
  /// - Returns: Result indicating success, failure with counterexample, or giving up
  public func runProperty<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    // Check for FailingExampleDatabase first (newer API)
    if let database = config.failingExampleDatabase,
      let testID = config.testIdentifier
    {
      let semaphore = DispatchSemaphore(value: 0)
      var result: PropertyResult<T>!
      Task {
        result = await runPropertyWithFailingExamples(
          property,
          config: config,
          database: database,
          testID: testID
        )
        semaphore.signal()
      }
      semaphore.wait()
      return result
    }

    // Legacy RegressionBank path
    if let bank = config.regressionBank, let propertyId = config.propertyId {
      let semaphore = DispatchSemaphore(value: 0)
      var result: PropertyResult<T>!
      Task {
        result = await runPropertyWithRegressions(
          property,
          config: config,
          bank: bank,
          propertyId: propertyId
        )
        semaphore.signal()
      }
      semaphore.wait()
      return result
    }
    return runPropertyCore(property, config: config)
  }

  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  private func runPropertyWithRegressions<T>(
    _ property: Property<T>,
    config: PropertyConfig,
    bank: RegressionBank,
    propertyId: String
  ) async -> PropertyResult<T> {
    let seedsToReplay = await bank.seedsForProperty(propertyId)

    for regressionSeed in seedsToReplay {
      let regressionRunner = PropertyRunner(seed: regressionSeed)
      let regressionResult = await regressionRunner.runProperty(property, config: config)

      switch regressionResult {
      case .failure:
        return regressionResult

      case .success, .gaveUp:
        continue
      }
    }

    let result = runPropertyCore(property, config: config)

    if case .failure(_, _, let shrunk, let reason, let seed) = result {
      let counterexampleStr = String(describing: shrunk)
      let entry = FailureEntry(
        propertyLabel: propertyId,
        seedValue: seed.rawValue,
        counterexampleDescription: counterexampleStr,
        failureReason: reason.description,
        failedAtIteration: 0
      )
      try? await bank.recordFailureEntry(entry)
    }

    return result
  }

  /// Run a property with FailingExampleDatabase integration.
  ///
  /// - Replays saved failures first (if replayFirst=true)
  /// - Marks examples as fixed if they now pass
  /// - Saves new failures to database
  /// - Continues with random generation after replay
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  private func runPropertyWithFailingExamples<T>(
    _ property: Property<T>,
    config: PropertyConfig,
    database: FailingExampleDatabase,
    testID: TestIdentifier
  ) async -> PropertyResult<T> {
    // Phase 1: Replay saved examples if replayFirst=true
    if config.replayFirst {
      let savedExamples = await database.examples(for: testID)
      let examplesToReplay = PropertyExecution.selectExamplesToReplay(
        savedExamples,
        maxExamples: config.maxReplayExamples
      )

      for example in examplesToReplay {
        let replayConfig = PropertyExecution.createReplayConfig(
          for: example,
          baseConfig: config
        )
        let replayResult = runPropertyCore(property, config: replayConfig)

        if case .failure(_, _, let shrunk, let reason, let failSeed) = replayResult {
          PropertyExecution.logReplayVerbose(
            "[Regression] Replayed failure still fails: \(example.inputDescription ?? "unknown")",
            verbose: config.verbose
          )
          return .failure(
            counterexample: shrunk,
            iterations: 0,
            shrunk: shrunk,
            reason: reason,
            seed: failSeed
          )
        }

        if case .success = replayResult {
          await database.markFixed(testID: testID, example: example)
          PropertyExecution.logReplayVerbose(
            "[Regression] Example now passes, marked as fixed",
            verbose: config.verbose
          )
        }
      }
    }

    // Phase 2: Run normal property test with random generation
    let result = runPropertyCore(property, config: config)

    // Phase 3: Save new failures to database
    if let failingExample = PropertyExecution.createFailingExample(from: result, config: config) {
      await database.save(testID: testID, example: failingExample)
      PropertyExecution.logSaveVerbose(verbose: config.verbose)
    }

    return result
  }

  func runPropertyCore<T>(
    _ property: Property<T>,
    config: PropertyConfig
  ) -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      if !property.predicate(testCase) {
        let shrunkCase = shrinkFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .predicateFailed,
          seed: seed
        )
      }

      successfulIterations += 1
    }

    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  /// Run a throwing property test and return the result.
  ///
  /// - Parameters:
  ///   - property: The throwing property to test
  ///   - config: Configuration for test execution
  ///
  /// - Returns: The result of running the property
  public func runThrowingProperty<T>(
    _ property: ThrowingProperty<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      if !property.assumption(testCase) {
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }
        continue
      }

      do {
        if try !property.predicate(testCase) {
          let shrunkCase = shrinkThrowingFailureWithTree(
            tree,
            property: property,
            maxShrinks: config.maxShrinks
          )
          return .failure(
            counterexample: testCase,
            iterations: successfulIterations + 1,
            shrunk: shrunkCase,
            reason: .predicateFailed,
            seed: seed
          )
        }
      } catch {
        let errorDescription = String(describing: error)
        let shrunkCase = shrinkThrowingFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: .threwError(errorDescription),
          seed: seed
        )
      }

      successfulIterations += 1
    }

    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      PropertyExecution.logDiscardWarning(message, config: config)

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }

  // MARK: - Evaluating Property Runner (S012)

  /// Run an evaluating property test and return the result.
  ///
  /// - Parameters:
  ///   - property: The evaluating property to test
  ///   - config: Configuration for test execution
  ///
  /// - Returns: The result of running the property
  public func runEvaluatingProperty<T>(
    _ property: EvaluatingProperty<T>,
    config: PropertyConfig = .default
  ) -> PropertyResult<T> {
    var discarded = 0
    var successfulIterations = 0

    while successfulIterations < config.iterations {
      let size = Size(value: min(successfulIterations, 100))
      let tree = property.generator.generateTree(&rng, size)
      let testCase = tree.value

      let evaluation = property.evaluate(testCase)

      switch evaluation {
      case .pass:
        successfulIterations += 1

      case .discard:
        discarded += 1
        if discarded > config.maxDiscarded {
          return .gaveUp(discarded: discarded, iterations: successfulIterations)
        }

      case .fail(let reason):
        let shrunkCase = shrinkEvaluatingFailureWithTree(
          tree,
          property: property,
          maxShrinks: config.maxShrinks
        )
        let failureReason: FailureReason = reason.map { .threwError($0) } ?? .predicateFailed
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: shrunkCase,
          reason: failureReason,
          seed: seed
        )
      }
    }

    let discardCheck = checkDiscardRatio(
      discarded: discarded,
      successful: successfulIterations,
      config: config
    )
    switch discardCheck {
    case .ok:
      break

    case .warn(let message):
      if config.verbose || config.verbosity == .verbose {
        print(message)  // swiftlint:disable:this no_print
      }

    case .fail:
      return .gaveUp(discarded: discarded, iterations: successfulIterations)
    }

    return .success(iterations: successfulIterations)
  }
}

// MARK: - Shrinking Helpers

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyRunner {

  /// Shrink an evaluating property failure using a pre-built shrink tree.
  func shrinkEvaluatingFailureWithTree<T>(
    _ tree: ShrinkTree<T>,
    property: EvaluatingProperty<T>,
    maxShrinks: Int
  ) -> T {
    let filteredTree = tree.filter { candidate in
      if case .discard = property.evaluate(candidate) {
        return false
      }
      return true
    }

    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      if case .fail = property.evaluate(candidate) {
        return true
      }
      return false
    }

    return minimal ?? tree.value
  }

  /// Shrink using a pre-built shrink tree (essential for flatMap dependent shrinking).
  func shrinkFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: Property<T>,
    maxShrinks: Int
  ) -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      !property.predicate(candidate)
    }

    return minimal ?? tree.value
  }

  /// Shrink a throwing property failure using a pre-built shrink tree.
  func shrinkThrowingFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: ThrowingProperty<T>,
    maxShrinks: Int
  ) -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = filteredTree.findMinimal(budget: maxShrinks) { candidate in
      do {
        return try !property.predicate(candidate)
      } catch {
        return true
      }
    }

    return minimal ?? tree.value
  }
}
