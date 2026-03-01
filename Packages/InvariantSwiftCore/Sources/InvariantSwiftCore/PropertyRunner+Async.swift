import Foundation

// MARK: - Async Property Runner

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PropertyRunner {

  /// Run an async property test and return the result.
  ///
  /// - Parameters:
  ///   - property: The async property to test
  ///   - config: Configuration for test execution
  ///
  /// - Returns: The result of running the property
  public func runAsyncProperty<T>(
    _ property: AsyncProperty<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T> {
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

      if await !property.predicate(testCase) {
        let shrunkCase = await shrinkAsyncFailureWithTree(
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

    // Check discard ratio before returning success
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

  /// Run an async throwing property test and return the result.
  ///
  /// - Parameters:
  ///   - property: The async throwing property to test
  ///   - config: Configuration for test execution
  ///
  /// - Returns: The result of running the property
  public func runAsyncThrowingProperty<T>(
    _ property: AsyncThrowingProperty<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T> {
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
        if try await !property.predicate(testCase) {
          let shrunkCase = await shrinkAsyncThrowingFailureWithTree(
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
        let shrunkCase = await shrinkAsyncThrowingFailureWithTree(
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

    // Check discard ratio before returning success
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

  /// Run a property test with per-iteration timeout enforcement.
  ///
  /// Similar to `runProperty`, but enforces a timeout for each predicate evaluation.
  /// If any iteration exceeds the configured timeout, the test fails with
  /// `FailureReason.timedOut`.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Configuration including timeout. If `config.timeout` is nil, uses 30.0s default.
  ///
  /// - Returns: The result of running the property, including `.timedOut` if timeout exceeded
  public func runPropertyWithTimeout<T>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) async -> PropertyResult<T> {
    let timeout = config.timeout ?? 30.0
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

      // Run predicate with timeout using deadline check
      let startTime = CFAbsoluteTimeGetCurrent()
      let passed = property.predicate(testCase)
      let elapsed = CFAbsoluteTimeGetCurrent() - startTime

      if elapsed > timeout {
        return .failure(
          counterexample: testCase,
          iterations: successfulIterations + 1,
          shrunk: testCase,  // No shrinking for timeout
          reason: .timedOut(seconds: timeout),
          seed: seed
        )
      }

      if !passed {
        // Property failed - use tree-based shrinking
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

    // Check discard ratio before returning success
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

  // MARK: - Async Shrinking Helpers

  func shrinkAsyncFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: AsyncProperty<T>,
    maxShrinks: Int
  ) async -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = await filteredTree.findMinimalAsync(budget: maxShrinks) { candidate in
      await !property.predicate(candidate)
    }

    return minimal ?? tree.value
  }

  func shrinkAsyncThrowingFailureWithTree<T: Sendable>(
    _ tree: ShrinkTree<T>,
    property: AsyncThrowingProperty<T>,
    maxShrinks: Int
  ) async -> T {
    let filteredTree = tree.filter { property.assumption($0) }

    let minimal = await filteredTree.findMinimalAsync(budget: maxShrinks) { candidate in
      do {
        return try await !property.predicate(candidate)
      } catch {
        return true
      }
    }

    return minimal ?? tree.value
  }

  // MARK: - Replay from Token

  /// Runs a property using a replay token to reproduce a previous failure.
  ///
  /// This enables deterministic reproduction of test failures by re-running
  /// with the exact seed and configuration captured in the token.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - token: The replay token from a previous failure
  ///
  /// - Returns: Result of running the property with the token's configuration
  public static func runFromToken<T>(
    _ property: Property<T>,
    token: ReplayToken
  ) async -> PropertyResult<T> {
    let config = token.toConfig()
    let runner = PropertyRunner(seed: Seed(value: token.seed))
    return await runner.runProperty(property, config: config)
  }

  /// Runs a throwing property using a replay token.
  ///
  /// - Parameters:
  ///   - property: The throwing property to test
  ///   - token: The replay token from a previous failure
  ///
  /// - Returns: Result of running the property with the token's configuration
  public static func runFromToken<T>(
    _ property: ThrowingProperty<T>,
    token: ReplayToken
  ) async -> PropertyResult<T> {
    let config = token.toConfig()
    let runner = PropertyRunner(seed: Seed(value: token.seed))
    return await runner.runThrowingProperty(property, config: config)
  }

  /// Runs an evaluating property using a replay token.
  ///
  /// - Parameters:
  ///   - property: The evaluating property to test
  ///   - token: The replay token from a previous failure
  ///
  /// - Returns: Result of running the property with the token's configuration
  public static func runFromToken<T>(
    _ property: EvaluatingProperty<T>,
    token: ReplayToken
  ) async -> PropertyResult<T> {
    let config = token.toConfig()
    let runner = PropertyRunner(seed: Seed(value: token.seed))
    return await runner.runEvaluatingProperty(property, config: config)
  }
}
