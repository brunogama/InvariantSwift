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
/// **Usage**:
/// ```swift
/// // Development configuration: fast feedback
/// let devConfig = ModelTestConfig(
///   maxCommands: 10,
///   maxShrinks: 100,
///   iterations: 20,
///   seed: nil
/// )
///
/// // Production configuration: thorough testing
/// let prodConfig = ModelTestConfig(
///   maxCommands: 50,
///   maxShrinks: 2000,
///   iterations: 500,
///   seed: nil
/// )
///
/// // Reproduce a specific failure
/// let reproduceConfig = ModelTestConfig(
///   maxCommands: 30,
///   maxShrinks: 1000,
///   iterations: 1,
///   seed: Seed(value: 12345)  // The seed from the failure report
/// )
/// ```
///
/// **Mathematical Perspective**:
/// The configuration parameters affect test effectiveness through coverage probability theory.
/// With `n` iterations and a state space of size `S`, the expected coverage approaches
/// `1 - (1 - 1/S)^n`. More iterations provide exponentially better coverage.
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
  /// **Setting a seed is essential for**:
  /// - Reproducing reported failures
  /// - Creating regression tests for bugs found during property testing
  /// - Debugging test framework issues
  ///
  /// **Omit the seed for**:
  /// - Regular development testing (want variation)
  /// - CI/CD pipelines (want different sequences each run)
  /// - Initial exploratory testing
  ///
  /// - Example:
  ///   ```swift
  ///   // From failure report: "Test failed with seed 5683091234"
  ///   let config = ModelTestConfig(seed: Seed(value: 5683091234))
  ///   ```
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
  ///
  /// - Example:
  ///   ```swift
  ///   let config = ModelTestConfig(
  ///     maxCommands: 30,
  ///     maxShrinks: 1500,
  ///     iterations: 200,
  ///     seed: nil
  ///   )
  ///   ```
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
  ///
  /// Suitable for most testing scenarios. Customize for specific needs.
  ///
  /// - Example:
  ///   ```swift
  ///   let result = await runner.runModelTest(model, config: .default)
  ///   ```
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
/// - **failure**: A command sequence violated an invariant or postcondition with minimal counterexample
/// - **gaveUp**: Too many command sequences were invalid, preventing thorough testing
///
/// **Usage**:
/// ```swift
/// let result = await runner.runModelTest(model, config: config)
///
/// switch result {
/// case .success(let iterations):
// swiftlint:disable:next no_print
///   print("All \(iterations) test iterations passed!")
///
/// case .failure(let commands, let failedCommand, let iterations, let shrunk):
// swiftlint:disable:next no_print
///   print("Failed after \(iterations) iterations")
// swiftlint:disable:next no_print
///   print("Minimal failing sequence: \(shrunk)")
///
/// case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///   print("Gave up after \(iterations) iterations (\(discarded) discarded)")
/// }
/// ```
///
/// - See Also: ``ModelTestRunner``, ``Command``, ``ModelTestConfig``
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
  ///   - commands: The original complete command sequence that triggered the failure
  ///   - failedCommand: The specific command in the sequence that violated the postcondition or invariant
  ///   - iterations: The iteration number (1-indexed) when failure was detected
  ///   - shrunk: The minimal command sequence that still exhibits the same failure
  case failure(
    commands: [CommandType],
    failedCommand: CommandType,
    iterations: Int,
    shrunk: [CommandType]
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
///
/// **Usage**:
/// ```swift
/// let runner = ModelTestRunner(seed: nil)
/// let result = await runner.runModelTest(myModel, config: .default)
/// ```
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
  ///
  /// - Returns: Result indicating success, failure with counterexample, or test incompleteness
  public func runModelTest<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default
  ) async -> ModelTestResult<Model.CommandType> {

    for iteration in 0..<config.iterations {
      do {
        let commands = try await generateCommandSequence(
          model: model,
          maxCommands: config.maxCommands
        )

        let result = try await executeCommandSequence(
          model: model,
          commands: commands
        )

        switch result {
        case .failure(let failedCommand):
          let shrunkCommands = try await shrinkCommandSequence(
            model: model,
            commands: commands,
            failedCommand: failedCommand,
            maxShrinks: config.maxShrinks
          )

          return .failure(
            commands: commands,
            failedCommand: failedCommand,
            iterations: iteration + 1,
            shrunk: shrunkCommands
          )

        case .success:
          continue
        }
      } catch {
        continue
      }
    }

    return .success(iterations: config.iterations)
  }

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

  /// Execute a sequence of commands and check for failures
  private func executeCommandSequence<Model: StateMachine>(
    model: Model,
    commands: [Model.CommandType]
  ) async throws -> ExecutionResult<Model.CommandType> {
    var currentState = model.initialState

    for command in commands {
      guard model.invariant(state: currentState) else {
        return .failure(command)
      }

      guard command.precondition(state: currentState) else {
        return .failure(command)
      }

      do {
        let result = try await command.execute()

        guard command.postcondition(state: currentState, result: result) else {
          return .failure(command)
        }

        currentState = command.apply(state: currentState)

        guard model.invariant(state: currentState) else {
          return .failure(command)
        }
      } catch {
        return .failure(command)
      }
    }

    return .success
  }

  /// Shrink a failed command sequence to find minimal counterexample
  private func shrinkCommandSequence<Model: StateMachine>(
    model: Model,
    commands: [Model.CommandType],
    failedCommand: Model.CommandType,
    maxShrinks: Int
  ) async throws -> [Model.CommandType] {
    var current = commands
    var shrinkAttempts = 0

    while shrinkAttempts < maxShrinks {
      let candidates = generateShrinkCandidates(commands: current)

      var foundBetter = false
      for candidate in candidates {
        let result = try await executeCommandSequence(model: model, commands: candidate)

        if case .failure = result {
          current = candidate
          foundBetter = true
          break
        }
      }

      if !foundBetter {
        break
      }

      shrinkAttempts += 1
    }

    return current
  }

  /// Generate shrinking candidates for a command sequence
  private func generateShrinkCandidates<C>(commands: [C]) -> [[C]] {
    var candidates: [[C]] = []

    for i in 0..<commands.count {
      var shrunk = commands
      shrunk.remove(at: i)
      if !shrunk.isEmpty {
        candidates.append(shrunk)
      }
    }

    if commands.count > 1 {
      candidates.append(Array(commands.dropFirst()))
      candidates.append(Array(commands.dropLast()))
    }

    return candidates
  }
}

// MARK: - ExecutionResult

/// Result of executing a command sequence (internal type)
private enum ExecutionResult<C> {
  case success
  case failure(C)
}

// MARK: - Convenience Extensions

extension ModelTestRunner {
  /// Run a model-based property test using a static convenience method
  ///
  /// - Parameters:
  ///   - model: The state machine model to test
  ///   - config: Configuration for the test run
  ///
  /// - Returns: The model test result
  public static func checkModel<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default
  ) async -> ModelTestResult<Model.CommandType> {
    let runner = ModelTestRunner(seed: config.seed)
    return await runner.runModelTest(model, config: config)
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
/// **How It Works**:
/// 1. Starts with the model's initial state
/// 2. For each step, generates a command valid in the current state using `model.generateCommand`
/// 3. Applies the command to update the model state
/// 4. Continues until reaching max commands or the size parameter
/// 5. Returns a complete valid command sequence
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
  /// Creates a `Gen` that produces valid command sequences. Each sequence:
  /// - Respects state machine preconditions
  /// - Follows valid state transitions
  /// - Contains 1 to `config.maxCommands` commands
  /// - Is completely deterministic given a seed and size
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
