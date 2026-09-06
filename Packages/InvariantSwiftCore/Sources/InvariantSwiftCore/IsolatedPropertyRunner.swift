import Foundation

/// Failure details from an isolated property run.
public struct IsolatedPropertyFailure<Value: Sendable>: Sendable {
  public let counterexample: Value
  public let shrunk: Value
  public let context: IsolatedPropertyFailureContext

  public init(
    counterexample: Value,
    shrunk: Value,
    context: IsolatedPropertyFailureContext
  ) {
    self.counterexample = counterexample
    self.shrunk = shrunk
    self.context = context
  }
}

/// Execution metadata associated with an isolated property failure.
public struct IsolatedPropertyFailureContext: Sendable {
  public let seed: Seed
  public let iterations: Int
  public let reason: String

  public init(seed: Seed, iterations: Int, reason: String) {
    self.seed = seed
    self.iterations = iterations
    self.reason = reason
  }
}

/// Result of a property test run with crash isolation.
public enum IsolatedPropertyResult<Value: Sendable>: Sendable {
  /// All iterations passed successfully.
  case success(iterations: Int)

  /// The property found a failing input.
  case failure(IsolatedPropertyFailure<Value>)

  /// Property execution crashed.
  case crashed(
    signal: Int32,
    counterexample: Value,
    shrunk: Value,
    iterations: Int
  )

  /// The run gave up after too many discards.
  case gaveUp(discards: Int)
}

private struct IsolationRunState {
  var seed: Seed
  var discards = 0

  mutating func advance() {
    seed = seed.next().next
  }
}

private struct IsolationIteration<Value: Sendable> {
  let property: Property<Value>
  let config: PropertyConfig
  let index: Int
}

private struct IsolationEvaluation<Value: Sendable> {
  let outcome: IsolationTestOutcome
  let value: Value
}

private struct IsolationShrinkRequest<Value: Sendable> {
  let property: Property<Value>
  let candidate: Value
  let config: PropertyConfig
  let expectation: IsolationShrinkExpectation
}

enum IsolationTestOutcome {
  case success
  case failure(reason: String)
  case crashed(signal: Int32)
  case discarded
}

private enum IsolationShrinkExpectation {
  case failure
  case crash

  func matches(_ outcome: IsolationTestOutcome) -> Bool {
    switch (self, outcome) {
    case (.failure, .failure), (.crash, .crashed):
      return true

    default:
      return false
    }
  }
}

/// Property runner with subprocess crash isolation.
public actor IsolatedPropertyRunner {
  public init() {
    _ = Self.self
  }

  /// Runs a property test with crash isolation.
  public func runProperty<Value: Sendable>(
    _ property: Property<Value>,
    config: PropertyConfig = .default
  ) async -> IsolatedPropertyResult<Value> {
    var state = IsolationRunState(seed: config.seed ?? .random)
    for index in 0..<config.iterations {
      let iteration = IsolationIteration(
        property: property,
        config: config,
        index: index
      )
      if let result = await run(iteration, state: &state) {
        return result
      }
    }
    return .success(iterations: config.iterations)
  }
}

extension IsolatedPropertyRunner {
  private func run<Value: Sendable>(
    _ iteration: IsolationIteration<Value>,
    state: inout IsolationRunState
  ) async -> IsolatedPropertyResult<Value>? {
    let value = generateValue(for: iteration, seed: state.seed)
    let outcome = await executeWithCrashDetection(
      property: iteration.property,
      value: value
    )
    let evaluation = IsolationEvaluation(outcome: outcome, value: value)
    return await resolve(evaluation, iteration: iteration, state: &state)
  }

  private func generateValue<Value: Sendable>(
    for iteration: IsolationIteration<Value>,
    seed: Seed
  ) -> Value {
    var generator: any RandomNumberGenerator =
      SeedBasedRandomNumberGenerator(seed: seed)
    let size = Size(value: min(iteration.index + 1, 100))
    return iteration.property.generator.generate(&generator, size)
  }

  private func resolve<Value: Sendable>(
    _ evaluation: IsolationEvaluation<Value>,
    iteration: IsolationIteration<Value>,
    state: inout IsolationRunState
  ) async -> IsolatedPropertyResult<Value>? {
    switch evaluation.outcome {
    case .success:
      state.advance()
      return nil

    case .failure:
      return await failureResult(evaluation, iteration, state)

    case .crashed(let signal):
      return await crashResult(evaluation.value, signal, iteration)

    case .discarded:
      return discardResult(iteration.config, state: &state)
    }
  }

  private func failureResult<Value: Sendable>(
    _ evaluation: IsolationEvaluation<Value>,
    _ iteration: IsolationIteration<Value>,
    _ state: IsolationRunState
  ) async -> IsolatedPropertyResult<Value> {
    guard case .failure(let reason) = evaluation.outcome else {
      return .success(iterations: iteration.index)
    }
    let request = IsolationShrinkRequest(
      property: iteration.property,
      candidate: evaluation.value,
      config: iteration.config,
      expectation: .failure
    )
    let context = IsolatedPropertyFailureContext(
      seed: state.seed,
      iterations: iteration.index + 1,
      reason: reason
    )
    let failure = IsolatedPropertyFailure(
      counterexample: evaluation.value,
      shrunk: await shrink(request) ?? evaluation.value,
      context: context
    )
    return .failure(failure)
  }

  private func crashResult<Value: Sendable>(
    _ value: Value,
    _ signal: Int32,
    _ iteration: IsolationIteration<Value>
  ) async -> IsolatedPropertyResult<Value> {
    let request = IsolationShrinkRequest(
      property: iteration.property,
      candidate: value,
      config: iteration.config,
      expectation: .crash
    )
    return .crashed(
      signal: signal,
      counterexample: value,
      shrunk: await shrink(request) ?? value,
      iterations: iteration.index + 1
    )
  }

  private func discardResult<Value: Sendable>(
    _ config: PropertyConfig,
    state: inout IsolationRunState
  ) -> IsolatedPropertyResult<Value>? {
    state.discards += 1
    guard state.discards < config.maxDiscarded else {
      return .gaveUp(discards: state.discards)
    }
    state.advance()
    return nil
  }

  private func shrink<Value: Sendable>(
    _ request: IsolationShrinkRequest<Value>
  ) async -> Value? {
    let candidates = request.property.generator.shrink.shrink(request.candidate)
    for candidate in candidates.prefix(request.config.maxShrinks) {
      let outcome = await executeWithCrashDetection(
        property: request.property,
        value: candidate
      )
      guard request.expectation.matches(outcome) else { continue }
      let next = IsolationShrinkRequest(
        property: request.property,
        candidate: candidate,
        config: request.config,
        expectation: request.expectation
      )
      return await shrink(next) ?? candidate
    }
    return nil
  }

  private func executeWithCrashDetection<Value: Sendable>(
    property: Property<Value>,
    value: Value
  ) async -> IsolationTestOutcome {
    #if os(macOS)
    guard let helperPath = findHelperExecutable() else {
      return property.predicate(value)
        ? .success : .failure(reason: "Property returned false")
    }
    return await executeInSubprocess(
      property: property,
      value: value,
      helperPath: helperPath
    )
    #else
    return .failure(reason: SubprocessRunner.unsupportedPlatformReason)
    #endif
  }

}

extension PropertyConfig {
  /// Creates a configuration for isolated crash-resistant testing.
  public static func isolated(
    iterations: Int = 100,
    maxShrinks: Int = 50,
    timeout: TimeInterval = 5.0
  ) -> PropertyConfig {
    _ = timeout
    return PropertyConfig(
      iterations: iterations,
      maxShrinks: maxShrinks
    )
  }
}
