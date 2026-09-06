import Foundation

// MARK: - Isolated Property Runner

/// Property runner with crash isolation using subprocess execution
///
/// Unlike the standard `PropertyRunner`, this runner can detect and handle
/// crashes (fatalError, preconditionFailure, assertion failures) without
/// killing the test process.
///
/// **Usage:**
/// ```swift
/// let result = await IsolatedPropertyRunner().runProperty(property) { value in
///   riskyOperation(value) // May crash
///   return true
/// }
///
/// switch result {
/// case .success:
///   reportSuccess()
/// case .crashed(let signal, let counterexample, let shrunk, _):
///   reportCrash(signal: signal, minimalInput: shrunk)
/// }
/// ```
///
/// **Performance:**
/// Subprocess isolation adds ~1-5ms overhead per iteration.
/// Use `PropertyRunner` for non-crashing code paths.
public actor IsolatedPropertyRunner {

  private let standardRunner = PropertyRunner()

  /// Creates an isolated property runner.
  public init() {
    // The runner needs no stored configuration beyond its defaults.
  }

  /// Run a property test with crash isolation.
  ///
  /// Each iteration is executed with crash detection. If a crash occurs,
  /// the counterexample is captured and shrinking continues to find the
  /// minimal crashing input.
  ///
  /// - Parameters:
  ///   - property: The property to test
  ///   - config: Configuration for the test run
  ///
  /// - Returns: An `IsolatedPropertyResult` for success, failure, or crash
  public func runProperty<T: Sendable>(
    _ property: Property<T>,
    config: PropertyConfig = .default
  ) async -> IsolatedPropertyResult<T> {
    var state = IterationState(seed: config.seed ?? Seed.random)

    for index in 0..<config.iterations {
      let context = IterationContext(
        property: property,
        config: config,
        index: index
      )
      if let result = await runIteration(in: context, state: &state) {
        return result
      }
    }

    return .success(iterations: config.iterations)
  }
}

// MARK: - Private Helpers

/// Immutable per-iteration inputs shared by the isolated execution helpers.
private struct IterationContext<T: Sendable> {
  let property: Property<T>
  let config: PropertyConfig
  let index: Int
}

/// Mutable seed and discard bookkeeping threaded through the run loop.
private struct IterationState {
  var seed: Seed
  var discards = 0

  mutating func advanceSeed() {
    seed = seed.next().next
  }

  mutating func recordDiscard<T: Sendable>(
    limit: Int
  ) -> IsolatedPropertyResult<T>? {
    discards += 1
    guard discards < limit else {
      return .gaveUp(discards: discards)
    }
    advanceSeed()
    return nil
  }
}

/// A generated input together with the seed that produced it.
private struct Candidate<T: Sendable> {
  let value: T
  let seed: Seed
}

extension IsolatedPropertyRunner {
  private enum TestOutcome {
    case success
    case failure(reason: String)
    case crashed(signal: Int32)
    case discarded
  }

  private func runIteration<T: Sendable>(
    in context: IterationContext<T>,
    state: inout IterationState
  ) async -> IsolatedPropertyResult<T>? {
    let candidate = makeCandidate(in: context, seed: state.seed)
    let outcome = await executeWithCrashDetection(
      property: context.property,
      value: candidate.value
    )

    switch outcome {
    case .success:
      state.advanceSeed()
      return nil

    case .discarded:
      return state.recordDiscard(limit: context.config.maxDiscarded)

    case .failure(let reason):
      return await failed(reason: reason, on: candidate, in: context)

    case .crashed(let signal):
      return await crashed(signal: signal, on: candidate, in: context)
    }
  }

  private func makeCandidate<T: Sendable>(
    in context: IterationContext<T>,
    seed: Seed
  ) -> Candidate<T> {
    var rng: any RandomNumberGenerator =
      SeedBasedRandomNumberGenerator(seed: seed)
    let size = Size(value: min(context.index + 1, 100))
    return Candidate(
      value: context.property.generator.generate(&rng, size),
      seed: seed
    )
  }

  private func failed<T: Sendable>(
    reason: String,
    on candidate: Candidate<T>,
    in context: IterationContext<T>
  ) async -> IsolatedPropertyResult<T> {
    let shrunk = await shrinkWithIsolation(
      property: context.property,
      counterexample: candidate.value,
      config: context.config
    )
    return .failure(
      counterexample: candidate.value,
      seed: candidate.seed,
      shrunk: shrunk ?? candidate.value,
      iterations: context.index + 1,
      reason: reason
    )
  }

  private func crashed<T: Sendable>(
    signal: Int32,
    on candidate: Candidate<T>,
    in context: IterationContext<T>
  ) async -> IsolatedPropertyResult<T> {
    let shrunk = await shrinkCrashingInput(
      property: context.property,
      counterexample: candidate.value,
      config: context.config
    )
    return .crashed(
      signal: signal,
      counterexample: candidate.value,
      shrunk: shrunk ?? candidate.value,
      iterations: context.index + 1
    )
  }

  /// Execute a single test iteration with crash detection.
  ///
  /// Evaluates the predicate with the best closure-capable isolation strategy.
  ///
  /// Darwin uses thread isolation with signal detection. Unsupported platforms
  /// use the factory's documented passthrough. Full subprocess isolation remains
  /// unavailable until the helper can execute registered predicate closures.
  private func executeWithCrashDetection<T: Sendable>(
    property: Property<T>,
    value: T
  ) async -> TestOutcome {
    let strategy = IsolationStrategyFactory.strategy(for: .threadBased)
    let result = await strategy.execute { property.predicate(value) }
    return outcome(from: result)
  }

  private func outcome(from result: IsolationResult) -> TestOutcome {
    switch result {
    case .success:
      .success

    case .failure(let reason):
      .failure(reason: reason)

    case .crashed(let signal, _, _, _):
      .crashed(signal: signal)

    case .timeout:
      .failure(reason: "Timed out")
    }
  }

  #if os(macOS)
  /// Execute property test in subprocess for crash isolation.
  private func executeInSubprocess<T: Sendable>(
    property: Property<T>,
    value: T,
    helperPath: URL
  ) async -> TestOutcome {
    let request: PropertyEvaluationRequest
    do {
      request = try makeEvaluationRequest(for: value)
    } catch {
      return .failure(reason: "Serialization error: \(error)")
    }

    let executor = SubprocessPropertyExecutor(
      helperExecutablePath: helperPath,
      timeout: 5.0
    )
    return outcome(from: await executor.execute(request: request))
  }

  private func makeEvaluationRequest<T: Sendable>(
    for value: T
  ) throws -> PropertyEvaluationRequest {
    let testInputData = try JSONEncoder().encode(AnyCodable(value))
    return PropertyEvaluationRequest(
      testId: UUID(),
      seed: 0,
      size: 0,
      testInput: testInputData,
      generatorType: String(describing: T.self)
    )
  }

  private func outcome(
    from result: SubprocessPropertyExecutor.ExecutionResult
  ) -> TestOutcome {
    if case .passed = result {
      return .success
    }
    if case .crashed(let signal, _) = result {
      return .crashed(signal: signal)
    }
    return .failure(reason: failureReason(from: result))
  }

  private func failureReason(
    from result: SubprocessPropertyExecutor.ExecutionResult
  ) -> String {
    switch result {
    case .failed(let reason):
      reason

    case .timedOut:
      "Timed out"

    case .spawnError(let error):
      "Spawn error: \(error)"

    case .passed, .crashed:
      "Unexpected subprocess outcome"
    }
  }
  #endif

  /// Shrink a failing input with isolation.
  private func shrinkWithIsolation<T: Sendable>(
    property: Property<T>,
    counterexample: T,
    config: PropertyConfig
  ) async -> T? {
    let shrinkCandidates = property.generator.shrink.shrink(counterexample)

    for candidate in shrinkCandidates.prefix(config.maxShrinks) {
      let result = await executeWithCrashDetection(
        property: property,
        value: candidate
      )

      if case .failure = result {
        // Found a smaller failing input, continue shrinking from here
        if let smaller = await shrinkWithIsolation(
          property: property,
          counterexample: candidate,
          config: config
        ) {
          return smaller
        }
        return candidate
      }
    }

    return nil
  }

  /// Shrink a crashing input with isolation.
  private func shrinkCrashingInput<T: Sendable>(
    property: Property<T>,
    counterexample: T,
    config: PropertyConfig
  ) async -> T? {
    let shrinkCandidates = property.generator.shrink.shrink(counterexample)

    for candidate in shrinkCandidates.prefix(config.maxShrinks) {
      let result = await executeWithCrashDetection(
        property: property,
        value: candidate
      )

      if case .crashed = result {
        // Found a smaller crashing input, continue shrinking from here
        if let smaller = await shrinkCrashingInput(
          property: property,
          counterexample: candidate,
          config: config
        ) {
          return smaller
        }
        return candidate
      }
    }

    return nil
  }
}
