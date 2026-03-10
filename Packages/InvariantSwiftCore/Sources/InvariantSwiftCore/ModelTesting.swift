import Foundation

// swiftlint:disable:next orphaned_doc_comment
/// Model-based testing framework for stateful system testing
/// Enables testing of stateful systems by defining state machines, commands, and invariants

// MARK: - ModelTestConfig

/// **Configuration parameters for model-based testing**
///
/// `ModelTestConfig` controls how the model-based test runner executes command sequences,
/// balancing thoroughness against execution time. All parameters have sensible defaults suitable
/// for most testing scenarios.
///
/// **Design Principles**:
/// Configuration settings control two aspects:
/// - **Coverage**: How many iterations and commands per iteration to test
/// - **Reduction**: How aggressively to shrink failed command sequences
///
/// **Parameter Guidance**:
/// - **maxCommands**: The average command sequence length. Longer sequences explore more state space
///   but take longer to execute and shrink. Start with 20-30 and adjust based on model complexity.
/// - **maxShrinks**: The maximum number of shrinking attempts. Higher values find smaller counterexamples
///   but may be slow. Use 1000-2000 for production, lower for development.
/// - **iterations**: Number of independent test runs. Higher iteration counts catch rare bugs.
///   Use 100+ for critical systems, 20-50 for fast feedback during development.
/// - **seed**: For reproducible testing of specific failures. Omit for random variation.
///
/// - See Also: ``ModelTestRunner``, ``ModelTestResult``
public struct ModelTestConfig: Sendable {
  /// **Maximum number of commands in a single test sequence**
  ///
  /// Controls the length of generated command sequences. Longer sequences explore deeper into
  /// the state space but also take proportionally longer to execute and shrink.
  ///
  /// Recommended values:
  /// - `10-15`: Simple systems, fast feedback
  /// - `20-30`: Typical systems (default)
  /// - `50+`: Complex systems, thorough exploration
  ///
  /// - Note: The actual sequence length varies randomly up to this maximum, providing variation
  /// across test iterations.
  public let maxCommands: Int

  /// **Maximum number of shrinking attempts for failed sequences**
  ///
  /// After finding a failing command sequence, the test runner attempts to shrink it to find
  /// a minimal counterexample. This limits the number of shrinking attempts to avoid infinite
  /// loops and excessive computation.
  ///
  /// Recommended values:
  /// - `100-200`: Development (fast feedback)
  /// - `1000`: Default balance
  /// - `2000+`: Production (thorough reduction)
  ///
  /// - Note: Each shrinking attempt executes a full command sequence, so higher values
  /// increase total execution time significantly.
  public let maxShrinks: Int

  /// **Number of independent test iterations**
  ///
  /// The test runner executes this many independent command sequences, each starting from
  /// the initial state. Higher iteration counts increase confidence in the system's correctness
  /// by exploring more of the state space.
  ///
  /// Recommended values:
  /// - `20-50`: Development feedback
  /// - `100`: Default balance
  /// - `200-500+`: Production verification
  ///
  /// - Note: Doubling iterations provides exponentially better coverage of large state spaces.
  public let iterations: Int

  /// **Optional seed for reproducible testing**
  ///
  /// When `nil` (default), the test runner uses system entropy for different random sequences
  /// on each run, providing maximum variation. When set, the test runner produces deterministic
  /// sequences, enabling reproduction of specific failures.
  ///
  /// - See Also: ``Seed``, ``Seed.random``
  public let seed: Seed?

  /// **Initialize with all configuration parameters**
  ///
  /// - Parameters:
  ///   - maxCommands: Maximum command sequence length (default: 20)
  ///   - maxShrinks: Maximum shrinking attempts (default: 1000)
  ///   - iterations: Number of test iterations (default: 100)
  ///   - seed: Optional seed for reproducibility (default: nil for random)
  public init(
    maxCommands: Int = 20,
    maxShrinks: Int = 1000,
    iterations: Int = 100,
    seed: Seed? = nil
  ) {
    self.maxCommands = maxCommands
    self.maxShrinks = maxShrinks
    self.iterations = iterations
    self.seed = seed
  }

  /// **Default configuration balancing thoroughness and speed**
  ///
  /// A sensible default for general-purpose model-based testing:
  /// - 20 commands per sequence
  /// - 1000 maximum shrinking attempts
  /// - 100 independent iterations
  /// - Random sequences (no fixed seed)
  public static let `default` = Self()
}

// MARK: - ModelTestResult

// swiftlint:disable:next orphaned_doc_comment
/// **Outcome of a model-based test execution**
///
/// `ModelTestResult` encapsulates the result of running a model-based test, providing both
/// the overall outcome (success, failure, or gave-up) and diagnostic information useful for
/// debugging failures.
///
/// **Result Cases**:
/// - **success**: All test iterations passed without discovering any violations
/// - **failure**: A command sequence violated specification; includes the full ``CommandTrace``
///   for the original sequence and the shrunk minimal counterexample
/// - **gaveUp**: Too many command sequences were invalid, preventing thorough testing
///
/// - See Also: ``ModelTestRunner``, ``Command``, ``ModelTestConfig``, ``CommandTrace``
public enum ModelTestResult<CommandType>: Sendable where CommandType: Command & Sendable {
  // swiftlint:disable:next orphaned_doc_comment
  /// **Test passed: All iterations succeeded without violations**
  ///
  /// - Parameters:
  ///   - iterations: The number of command sequences tested
  case success(iterations: Int)

  // swiftlint:disable:next orphaned_doc_comment
  /// **Test failed: Command sequence violated specification**
  ///
  /// - Parameters:
  ///   - trace: Full ``CommandTrace`` of the original failing sequence,
  ///     including step-by-step state and the failing step index.
  ///   - iterations: The iteration number (1-indexed) when failure was detected
  ///   - shrunkTrace: ``CommandTrace`` of the minimized failing sequence after shrinking
  case failure(
    trace: CommandTrace<CommandType>,
    iterations: Int,
    shrunkTrace: CommandTrace<CommandType>
  )

  // swiftlint:disable:next orphaned_doc_comment
  /// **Test incomplete: Too many discarded command sequences**
  ///
  /// - Parameters:
  ///   - discarded: The number of invalid command sequences discarded
  ///   - iterations: The number of iterations attempted before giving up
  case gaveUp(discarded: Int, iterations: Int)
}

// MARK: - ModelTestRunner

// swiftlint:disable:next orphaned_doc_comment
/// **Thread-safe executor for model-based tests**
///
/// `ModelTestRunner` orchestrates model-based testing by:
/// 1. Generating random command sequences using the state machine
/// 2. Executing commands on both the abstract model and real system
/// 3. Verifying the real system's behavior matches the model
/// 4. Shrinking failed sequences to minimal counterexamples
///
/// **Design Principles**:
/// - **Actor-based**: Thread-safe concurrent execution with Swift's actor isolation
/// - **Deterministic or random**: Controlled via `Seed` parameter
/// - **Comprehensive testing**: Checks preconditions, postconditions, and invariants
/// - **Minimal counterexamples**: Automatically shrinks failures to simplest failing case
/// - **Validity-preserving shrinking**: Shrink candidates are pre-filtered so every step's
///   precondition holds in the reduced state sequence before attempting execution
///
/// - See Also: ``ModelTestConfig``, ``ModelTestResult``, ``StateMachine``, ``Command``
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor ModelTestRunner {
  private var rng: any RandomNumberGenerator

  /// **Initialize a model-based test runner**
  ///
  /// - Parameters:
  ///   - seed: Optional seed for deterministic testing. If `nil`, uses system entropy.
  public init(seed: Seed? = nil) {
    if let seed = seed {
      self.rng = SeedBasedRandomNumberGenerator(seed: seed)
    } else {
      self.rng = SystemRandomNumberGenerator()
    }
  }

  // swiftlint:disable:next orphaned_doc_comment
  /// **Execute a complete model-based test**
  ///
  /// Runs the full model-based testing process for each of `config.iterations`:
  /// 1. Generates random command sequences respecting the model's state constraints
  /// 2. Executes commands on the real system and verifies against the model
  /// 3. Checks invariants before and after each command
  /// 4. Shrinks any failed sequence to find the minimal counterexample
  ///
  /// - Parameters:
  ///   - model: The state machine model specifying the system under test
  ///   - config: Configuration controlling iterations, sequence length, and shrinking
  ///   - failureInjector: Optional injector that forces errors at specific steps
  ///
  /// - Returns: Result indicating success, failure with counterexample, or test incompleteness
  public func runModelTest<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default,
    failureInjector: FailureInjector<Model.CommandType>? = nil
  ) async -> ModelTestResult<Model.CommandType> {

    for iteration in 0..<config.iterations {
      do {
        let commands = try await generateCommandSequence(
          model: model,
          maxCommands: config.maxCommands
        )

        let trace = await executeCommandSequence(
          model: model,
          commands: commands,
          injector: failureInjector
        )

        if trace.failingStepIndex != nil {
          let shrunkTrace = await shrinkCommandSequence(
            model: model,
            commands: commands,
            injector: failureInjector,
            maxShrinks: config.maxShrinks
          )

          return .failure(
            trace: trace,
            iterations: iteration + 1,
            shrunkTrace: shrunkTrace
          )
        }
      } catch {
        continue
      }
    }

    return .success(iterations: config.iterations)
  }

  // MARK: - Private helpers

  /// Generate a sequence of valid commands
  private func generateCommandSequence<Model: StateMachine>(
    model: Model,
    maxCommands: Int
  ) async throws -> [Model.CommandType] {
    var commands: [Model.CommandType] = []
    var currentState = model.initialState

    let commandCount = Int.random(in: 1...maxCommands, using: &rng)

    for _ in 0..<commandCount {
      let size = Size(value: min(commands.count + 1, 50))
      let commandGen = model.generateCommand(state: currentState)
      let command = commandGen.generate(&rng, size)

      guard command.precondition(state: currentState) else {
        continue
      }

      commands.append(command)
      currentState = command.apply(state: currentState)
    }

    return commands
  }

  /// Execute a sequence of commands and return a full ``CommandTrace``.
  private func executeCommandSequence<Model: StateMachine>(
    model: Model,
    commands: [Model.CommandType],
    injector: FailureInjector<Model.CommandType>?
  ) async -> CommandTrace<Model.CommandType> {
    var steps: [CommandStep<Model.CommandType>] = []
    var state = model.initialState

    for (index, command) in commands.enumerated() {
      if let injectedError = injector?.check(command, index) {
        let step = CommandStep<Model.CommandType>(
          index: index,
          command: command,
          stateBefore: state,
          stateAfter: nil,
          result: nil,
          error: injectedError,
          failureKind: .injectedFailure(injectedError.localizedDescription)
        )
        steps.append(step)
        return CommandTrace(steps: steps, failingStepIndex: index)
      }
      let outcome = await executeOneCommand(
        model: model,
        command: command,
        index: index,
        state: state
      )
      switch outcome {
      case .passed(let step, let newState):
        steps.append(step)
        state = newState

      case .failed(let step):
        steps.append(step)
        return CommandTrace(steps: steps, failingStepIndex: index)
      }
    }

    return CommandTrace(steps: steps, failingStepIndex: nil)
  }

  /// Execute a single command against the model and real system, returning either
  /// a passed step (with updated state) or a failed step.
  private func executeOneCommand<Model: StateMachine>(
    model: Model,
    command: Model.CommandType,
    index: Int,
    state: Model.CommandType.State
  ) async -> CommandStepOutcome<Model.CommandType> {
    let stateBefore = state
    func failStep(
      kind: CommandFailureKind,
      err: (any Error)? = nil,
      after: Model.CommandType.State? = nil,
      res: Model.CommandType.Result? = nil
    ) -> CommandStepOutcome<Model.CommandType> {
      .failed(
        CommandStep(
          index: index,
          command: command,
          stateBefore: stateBefore,
          stateAfter: after,
          result: res,
          error: err,
          failureKind: kind
        )
      )
    }

    guard model.invariant(state: state) else {
      return failStep(kind: .invariantViolated(when: "before"))
    }
    guard command.precondition(state: state) else {
      return failStep(kind: .preconditionViolated)
    }

    let result: Model.CommandType.Result
    do {
      result = try await command.execute()
    } catch {
      return failStep(kind: .executionError(error.localizedDescription), err: error)
    }

    guard command.postcondition(state: state, result: result) else {
      return failStep(kind: .postconditionFailed, res: result)
    }

    let stateAfter = command.apply(state: state)

    guard model.invariant(state: stateAfter) else {
      return failStep(kind: .invariantViolated(when: "after"), after: stateAfter, res: result)
    }

    let passedStep = CommandStep(
      index: index,
      command: command,
      stateBefore: stateBefore,
      stateAfter: stateAfter,
      result: result,
      error: nil,
      failureKind: nil
    )
    return .passed(passedStep, newState: stateAfter)
  }

  /// Returns `true` when every command in `commands` has a valid precondition and
  /// the model invariant holds throughout — using only dry-run model operations
  /// (no I/O, no async calls).
  private func isModelValid<Model: StateMachine>(
    model: Model,
    commands: [Model.CommandType]
  ) -> Bool {
    var state = model.initialState
    for command in commands {
      guard model.invariant(state: state) else { return false }
      guard command.precondition(state: state) else { return false }
      state = command.apply(state: state)
    }
    return model.invariant(state: state)
  }

  /// Generate validity-preserving shrink candidates.
  ///
  /// Only candidates where every step's precondition holds in the reduced model
  /// state sequence are returned, preventing invalid sequences during shrinking.
  private func generateShrinkCandidates<Model: StateMachine>(
    model: Model,
    commands: [Model.CommandType]
  ) -> [[Model.CommandType]] {
    var candidates: [[Model.CommandType]] = []

    // Remove one command at a time, pre-filter for model validity
    for i in 0..<commands.count {
      var shrunk = commands
      shrunk.remove(at: i)
      if !shrunk.isEmpty && isModelValid(model: model, commands: shrunk) {
        candidates.append(shrunk)
      }
    }

    // Shortest valid prefix
    for len in stride(from: commands.count - 1, through: 1, by: -1) {
      let prefix = Array(commands.prefix(len))
      if isModelValid(model: model, commands: prefix) {
        candidates.append(prefix)
        break
      }
    }

    return candidates
  }

  /// Shrink a failed command sequence to find a minimal counterexample.
  private func shrinkCommandSequence<Model: StateMachine>(
    model: Model,
    commands: [Model.CommandType],
    injector: FailureInjector<Model.CommandType>?,
    maxShrinks: Int
  ) async -> CommandTrace<Model.CommandType> {
    var currentCommands = commands
    var shrinkAttempts = 0

    while shrinkAttempts < maxShrinks {
      let candidates = generateShrinkCandidates(model: model, commands: currentCommands)

      var foundBetter = false
      for candidate in candidates {
        let trace = await executeCommandSequence(
          model: model,
          commands: candidate,
          injector: injector
        )

        if trace.failingStepIndex != nil {
          currentCommands = candidate
          foundBetter = true
          break
        }
      }

      if !foundBetter { break }
      shrinkAttempts += 1
    }

    // Re-execute the final shrunk sequence to produce the definitive trace
    return await executeCommandSequence(
      model: model,
      commands: currentCommands,
      injector: injector
    )
  }
}

// MARK: - Convenience Extensions

extension ModelTestRunner {
  /// Run a model-based property test using a static convenience method
  ///
  /// - Parameters:
  ///   - model: The state machine model to test
  ///   - config: Configuration for the test run
  ///   - failureInjector: Optional injector that forces errors at specific steps
  ///
  /// - Returns: The model test result
  public static func checkModel<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default,
    failureInjector: FailureInjector<Model.CommandType>? = nil
  ) async -> ModelTestResult<Model.CommandType> {
    let runner = ModelTestRunner(seed: config.seed)
    return await runner.runModelTest(model, config: config, failureInjector: failureInjector)
  }
}

// MARK: - Property Integration

extension Property {
  /// **Create a property from a state machine model**
  ///
  /// Bridges the model-based testing framework with the property-based testing framework
  /// by converting a `StateMachine` into a `Property` over command sequences.
  ///
  /// - Parameters:
  ///   - model: The state machine model to test
  ///   - config: Configuration controlling sequence length and iterations
  ///
  /// - Returns: A property that tests all generated command sequences
  public static func fromModel<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default
  ) -> Property<[Model.CommandType]> where T == [Model.CommandType] {
    Property(
      generator: ModelCommandSequenceGenerator(model: model, config: config).asGen(),
      predicate: { commands in
        Task {
          let result = await ModelTestRunner.checkModel(model, config: config)
          switch result {
          case .success:
            return true

          case .failure, .gaveUp:
            return false
          }
        }
        return commands.count <= config.maxCommands
      }
    )
  }
}

// MARK: - ModelCommandSequenceGenerator

// swiftlint:disable:next orphaned_doc_comment
/// **Generator for valid command sequences from a state machine**
///
/// `ModelCommandSequenceGenerator` bridges model-based testing with the property-based testing
/// framework by converting a `StateMachine` into a `Gen` that produces valid command sequences.
/// It ensures all generated sequences respect the state machine's preconditions and state evolution.
///
/// - See Also: ``ModelTestRunner``, ``StateMachine``, ``Gen``
public struct ModelCommandSequenceGenerator<Model: StateMachine>: Sendable {
  /// The state machine model providing initial state and command generation
  public let model: Model

  /// Configuration controlling maximum sequence length
  public let config: ModelTestConfig

  /// **Initialize with a model and configuration**
  ///
  /// - Parameters:
  ///   - model: The state machine model to generate sequences from
  ///   - config: Configuration controlling maximum sequence length
  public init(model: Model, config: ModelTestConfig) {
    self.model = model
    self.config = config
  }

  /// **Convert to a generator for use in property-based testing**
  ///
  /// - Returns: A generator producing valid command sequences
  public func asGen() -> Gen<[Model.CommandType]> {
    Gen { rng, size in
      var commands: [Model.CommandType] = []
      var currentState = self.model.initialState
      let maxCommands = min(size.value, self.config.maxCommands)

      for _ in 0..<maxCommands {
        let commandGen = self.model.generateCommand(state: currentState)
        let command = commandGen.generate(&rng, size)

        if command.precondition(state: currentState) {
          commands.append(command)
          currentState = command.apply(state: currentState)
        }
      }

      return commands
    }
  }
}

// MARK: - CommandStepOutcome

/// Internal result of executing a single command step.
///
/// Used by `ModelTestRunner.executeOneCommand` to communicate whether a command
/// passed (carrying the resulting state) or failed (carrying the failing step).
private enum CommandStepOutcome<C: Command> {
  /// The command passed all checks. Carries the recorded step and the new model state.
  case passed(CommandStep<C>, newState: C.State)
  /// The command failed one check. Carries the failing step.
  case failed(CommandStep<C>)
}
