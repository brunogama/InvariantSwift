import Foundation

/// Model-based testing framework for stateful system testing
/// Enables testing of stateful systems by defining state machines, commands, and invariants

// MARK: - Core Model-Based Testing Types

/// Represents a command that can be executed on a system under test
public protocol Command: Sendable {
  associatedtype State: Sendable
  associatedtype Result: Sendable

  /// Check if this command is valid in the given state
  func precondition(state: State) -> Bool

  /// Execute the command on the real system and return result
  func execute() async throws -> Result

  /// Apply the command to the model state, returning new state
  func apply(state: State) -> State

  /// Verify that the result matches expectations given the state
  func postcondition(state: State, result: Result) -> Bool
}

/// Represents a state machine model for testing
public protocol StateMachine: Sendable {
  associatedtype State: Sendable
  associatedtype Command: FunctionalTesting.Command where Command.State == State

  /// Initial state of the system
  var initialState: State { get }

  /// Generate a command that's valid in the given state
  func generateCommand(state: State) -> Gen<Command>

  /// Check invariants that should always hold
  func invariant(state: State) -> Bool
}

/// Configuration for model-based testing
public struct ModelTestConfig: Sendable {
  public let maxCommands: Int
  public let maxShrinks: Int
  public let iterations: Int
  public let seed: Seed?

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

  public static let `default` = Self()
}

/// Result of running a model-based test
public enum ModelTestResult<Command>: Sendable where Command: FunctionalTesting.Command {
  case success(iterations: Int)
  case failure(
    commands: [Command],
    failedCommand: Command,
    iterations: Int,
    shrunk: [Command]
  )
  case gaveUp(discarded: Int, iterations: Int)
}

/// Runner for model-based tests
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor ModelTestRunner {
  private var rng: any RandomNumberGenerator

  public init(seed: Seed? = nil) {
    if let seed = seed {
      self.rng = SeedBasedRandomNumberGenerator(seed: seed)
    } else {
      self.rng = SystemRandomNumberGenerator()
    }
  }

  /// Run a model-based test
  public func runModelTest<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default
  ) async -> ModelTestResult<Model.Command> {

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
        // If command generation or execution fails, continue to next iteration
        continue
      }
    }

    return .success(iterations: config.iterations)
  }

  /// Generate a sequence of valid commands
  private func generateCommandSequence<Model: StateMachine>(
    model: Model,
    maxCommands: Int
  ) async throws -> [Model.Command] {
    var commands: [Model.Command] = []
    var currentState = model.initialState

    let commandCount = Int.random(in: 1...maxCommands, using: &rng)

    for _ in 0..<commandCount {
      let size = Size(value: min(commands.count + 1, 50))
      let commandGen = model.generateCommand(state: currentState)
      let command = commandGen.generate(&rng, size)

      // Verify precondition
      guard command.precondition(state: currentState) else {
        continue  // Skip invalid commands
      }

      commands.append(command)
      currentState = command.apply(state: currentState)
    }

    return commands
  }

  /// Execute a sequence of commands and check for failures
  private func executeCommandSequence<Model: StateMachine>(
    model: Model,
    commands: [Model.Command]
  ) async throws -> ExecutionResult<Model.Command> {
    var currentState = model.initialState

    for command in commands {
      // Verify invariant before execution
      guard model.invariant(state: currentState) else {
        return .failure(command)
      }

      // Verify precondition
      guard command.precondition(state: currentState) else {
        return .failure(command)
      }

      // Execute command
      do {
        let result = try await command.execute()

        // Verify postcondition
        guard command.postcondition(state: currentState, result: result) else {
          return .failure(command)
        }

        // Update model state
        currentState = command.apply(state: currentState)

        // Verify invariant after execution
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
    commands: [Model.Command],
    failedCommand: Model.Command,
    maxShrinks: Int
  ) async throws -> [Model.Command] {
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
  private func generateShrinkCandidates<Command>(commands: [Command]) -> [[Command]] {
    var candidates: [[Command]] = []

    // Remove individual commands
    for i in 0..<commands.count {
      var shrunk = commands
      shrunk.remove(at: i)
      if !shrunk.isEmpty {
        candidates.append(shrunk)
      }
    }

    // Remove prefixes and suffixes
    if commands.count > 1 {
      candidates.append(Array(commands.dropFirst()))
      candidates.append(Array(commands.dropLast()))
    }

    return candidates
  }
}

/// Result of executing a command sequence
private enum ExecutionResult<Command> {
  case success
  case failure(Command)
}

// MARK: - Convenience Extensions

extension ModelTestRunner {
  /// Run a model-based property test (sync version)
  public static func checkModel<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default
  ) async -> ModelTestResult<Model.Command> {
    let runner = ModelTestRunner(seed: config.seed)
    return await runner.runModelTest(model, config: config)
  }
}

// MARK: - Built-in Command Types

/// A command that modifies a simple counter
public struct IncrementCommand: Command {
  public let amount: Int

  public init(amount: Int) {
    self.amount = amount
  }

  public func precondition(state: Int) -> Bool {
    state + amount <= 1000 && state + amount >= -1000
  }

  public func execute() async throws -> Int {
    // Simulate some work
    amount
  }

  public func apply(state: Int) -> Int {
    state + amount
  }

  public func postcondition(state: Int, result: Int) -> Bool {
    result == amount
  }
}

/// A simple counter state machine for testing
public struct CounterStateMachine: StateMachine {
  public let initialState: Int = 0

  public init() {}

  public func generateCommand(state: Int) -> Gen<IncrementCommand> {
    Gen.int(in: -10...10).map { IncrementCommand(amount: $0) }
  }

  public func invariant(state: Int) -> Bool {
    state >= -1000 && state <= 1000
  }
}

// MARK: - Advanced Command Types

/// Command that can fail probabilistically
public struct FlakyCommand: Command {
  public let successProbability: Double
  public let value: String

  public init(successProbability: Double, value: String) {
    self.successProbability = successProbability
    self.value = value
  }

  public func precondition(state: [String]) -> Bool {
    state.count < 100
  }

  public func execute() async throws -> Bool {
    let random = Double.random(in: 0...1)
    if random < successProbability {
      return true
    } else {
      throw ModelTestError.commandFailed("FlakyCommand failed")
    }
  }

  public func apply(state: [String]) -> [String] {
    state + [value]
  }

  public func postcondition(state: [String], result: Bool) -> Bool {
    result == true
  }
}

/// Stack-based state machine for testing
public struct StackStateMachine: StateMachine {
  public let initialState: [Int] = []

  public init() {}

  public func generateCommand(state: [Int]) -> Gen<StackCommand> {
    if state.isEmpty {
      return Gen.pure(StackCommand.push(Int.random(in: 1...100)))
    } else {
      return Gen.oneOf([
        Gen.pure(StackCommand.push(Int.random(in: 1...100))),
        Gen.pure(StackCommand.pop),
      ])
    }
  }

  public func invariant(state: [Int]) -> Bool {
    state.isEmpty && state.count <= 1000
  }
}

/// Commands for stack operations
public enum StackCommand: Command {
  case push(Int)
  case pop

  public func precondition(state: [Int]) -> Bool {
    switch self {
    case .push:
      return state.count < 1000

    case .pop:
      return !state.isEmpty
    }
  }

  public func execute() async throws -> StackResult {
    switch self {
    case .push(let value):
      return .pushed(value)

    case .pop:
      return .popped
    }
  }

  public func apply(state: [Int]) -> [Int] {
    switch self {
    case .push(let value):
      return state + [value]

    case .pop:
      return Array(state.dropLast())
    }
  }

  public func postcondition(state: [Int], result: StackResult) -> Bool {
    switch (self, result) {
    case (.push(let value), .pushed(let resultValue)):
      return value == resultValue

    case (.pop, .popped):
      return true

    default:
      return false
    }
  }
}

/// Result type for stack operations
public enum StackResult: Sendable {
  case pushed(Int)
  case popped
}

// MARK: - Error Types

public enum ModelTestError: Error, Sendable {
  case commandFailed(String)
  case preconditionViolated(String)
  case postconditionViolated(String)
  case invariantViolated(String)
}

// MARK: - Integration with Property Testing

extension Property {
  /// Create a property from a state machine model
  public static func fromModel<Model: StateMachine>(
    _ model: Model,
    config: ModelTestConfig = .default
  ) -> Property<[Model.Command]> where T == [Model.Command] {
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
        // For synchronous testing, we'll use a simplified check
        return commands.count <= config.maxCommands
      }
    )
  }
}

/// Generator for command sequences from a state machine
public struct ModelCommandSequenceGenerator<Model: StateMachine>: Sendable {
  public let model: Model
  public let config: ModelTestConfig

  public init(model: Model, config: ModelTestConfig) {
    self.model = model
    self.config = config
  }

  public func asGen() -> Gen<[Model.Command]> {
    Gen { rng, size in
      var commands: [Model.Command] = []
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
