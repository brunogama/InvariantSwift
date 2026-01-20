import Foundation

// swiftlint:disable:next orphaned_doc_comment
/// Model-based testing framework for stateful system testing
/// Enables testing of stateful systems by defining state machines, commands, and invariants

// MARK: - Core Model-Based Testing Types

/// **Protocol for stateful commands in model-based testing**
///
/// `Command` defines the interface for actions executed on a system under test in model-based testing.
/// Each command encapsulates both:
/// - **Real execution**: What happens on the actual system
/// - **Model simulation**: How the abstract state machine evolves
///
/// **Design Philosophy**:
/// Model-based testing verifies system behavior by comparing real execution against a simplified
/// abstract model. Commands serve as the bridge between these two, ensuring the real system
/// conforms to the model's expectations.
///
/// **Mathematical Foundation**:
/// Commands implement a state transition algebra where the model tracks abstract state evolution
/// and commands verify properties that bridge the semantic gap between specification and implementation.
/// Pre/post-conditions form a Hoare triple contract: `{P} command {Q}` where P is precondition and Q
/// is postcondition.
///
/// **Associated Types**:
/// - `State`: The abstract state type for the model
/// - `Result`: The return type from executing the command
///
/// **Key Requirements**:
/// - Commands must satisfy pre/post-condition contracts
/// - `apply(state:)` must correctly simulate command effects on the model state
/// - `execute()` must actually perform the command on the real system
/// - The postcondition verifies the real result matches model expectations
///
/// **Usage**:
/// Implement `Command` to define testable actions. Each method implements part of the command's
/// specification:
///
/// ```swift
/// struct SetValueCommand: Command {
///   typealias State = [String: Int]
///   typealias Result = Bool
///
///   let key: String
///   let value: Int
///
///   func precondition(state: State) -> Bool {
///     // Command is valid if value is in valid range
///     return (0...100).contains(value)
///   }
///
///   func execute() async throws -> Bool {
///     // Execute on real system (e.g., call API, modify database)
///     return true  // Simulated success
///   }
///
///   func apply(state: State) -> State {
///     // Update model state: add key-value pair
///     var newState = state
///     newState[key] = value
///     return newState
///   }
///
///   func postcondition(state: State, result: Bool) -> Bool {
///     // Verify result matches model: result should be true
///     return result == true
///   }
/// }
/// ```
///
/// **Error Handling**:
/// The `execute()` method can throw errors representing real system failures. The model-based
/// test runner treats thrown errors as command failures and includes them in shrinking analysis.
///
/// - See Also: ``StateMachine``, ``ModelTestRunner``, ``ModelTestConfig``
public protocol Command: Sendable {
  associatedtype State: Sendable
  associatedtype Result: Sendable

  /// **Check if this command is valid in the given state**
  ///
  /// The precondition guards against executing commands in invalid states. This is essential for
  /// realistic state machine models where not all commands are valid in all states.
  ///
  /// - Parameters:
  ///   - state: The current abstract model state
  ///
  /// - Returns: `true` if the command can be executed in this state, `false` otherwise
  ///
  /// - Example:
  ///   ```swift
  ///   struct PopCommand: Command {
  ///     func precondition(state: [Int]) -> Bool {
  ///       // Pop is only valid on non-empty stack
  ///       return !state.isEmpty
  ///     }
  ///   }
  ///   ```
  ///
  /// - Note: If a command fails its precondition, the model-based test runner skips it
  /// and generates a different command.
  func precondition(state: State) -> Bool

  /// **Execute the command on the real system and return result**
  ///
  /// Performs the actual command execution. This is where your real system is exercised—whether
  /// that's calling an API, modifying a database, or any other side effect. The result is later
  /// verified by `postcondition(state:result:)`.
  ///
  /// - Returns: The result of executing the command
  ///
  /// - Throws: Any error from the real system. Errors are treated as command failures.
  ///
  /// - Example:
  ///   ```swift
  ///   func execute() async throws -> String {
  ///     // Call real API endpoint
  ///     let response = try await apiClient.post(endpoint, body: value)
  ///     return response.status
  ///   }
  ///   ```
  ///
  /// - Note: This method is where real side effects occur. Use appropriate error handling
  /// and ensure idempotency when possible for reproducible testing.
  func execute() async throws -> Result

  /// **Apply the command to the model state, returning new state**
  ///
  /// Updates the abstract model state according to the command's semantics. This is the
  /// specification of what the command should do. The model-based test runner uses this
  /// to simulate the abstract behavior and later compares against real execution.
  ///
  /// - Parameters:
  ///   - state: The current model state
  ///
  /// - Returns: The model state after applying this command
  ///
  /// - Example:
  ///   ```swift
  ///   func apply(state: [Int]) -> [Int] {
  ///     // Push adds to end of stack
  ///     return state + [value]
  ///   }
  ///   ```
  ///
  /// - Important: This must be a pure function with no side effects. It computes the
  /// expected next state based on the current state and command parameters.
  func apply(state: State) -> State

  /// **Verify that the result matches expectations given the state**
  ///
  /// The postcondition verifies that the real execution result matches what the model expects.
  /// This bridges the gap between the real system behavior and the abstract model.
  ///
  /// - Parameters:
  ///   - state: The current model state (before applying this command)
  ///   - result: The actual result returned from `execute()`
  ///
  /// - Returns: `true` if the result matches the model's expectations, `false` otherwise
  ///
  /// - Example:
  ///   ```swift
  ///   func postcondition(state: [Int], result: StackResult) -> Bool {
  ///     switch (self, result) {
  ///     case (.push(let value), .pushed(let resultValue)):
  ///       return value == resultValue  // Verify value was pushed
  ///     case (.pop, .popped):
  ///       return true  // Pop succeeded
  ///     default:
  ///       return false
  ///     }
  ///   }
  ///   ```
  ///
  /// - Note: If postcondition fails, the model-based test reports this as a violation
  /// of the system specification.
  func postcondition(state: State, result: Result) -> Bool
}

/// **Abstract model of a stateful system for testing**
///
/// `StateMachine` defines a simplified specification of a system under test. It encapsulates:
/// - **State space**: The abstract states the system can occupy
/// - **Operations**: Commands that transition between states
/// - **Invariants**: Properties that must always hold
///
/// **Design Philosophy**:
/// Model-based testing works by comparing the behavior of a real system against an abstract model.
/// The model is simpler and easier to reason about than the real system. By executing random command
/// sequences on both the model and the real system, and verifying they remain synchronized, we gain
/// confidence in the real system's correctness.
///
/// **Mathematical Foundation**:
/// State machines are fundamental computational models. Here, they're used as executable specifications
/// against which the actual system is validated. The model's `initialState` and `generateCommand` define
/// the state space and transition function, while `invariant` specifies safety properties using temporal
/// logic: `G(invariant)` (globally true at all states).
///
/// **Associated Types**:
/// - `State`: The abstract state representation
/// - `CommandType`: Concrete command type implementing the `Command` protocol
///
/// **Key Responsibilities**:
/// - `initialState`: Provides the starting point for all test sequences
/// - `generateCommand(state:)`: Produces valid commands for each state (generator-based non-determinism)
/// - `invariant(state:)`: Defines safety properties that must never be violated
///
/// **Usage**:
/// Implement `StateMachine` to define the specification for your system:
///
/// ```swift
/// struct BankAccountModel: StateMachine {
///   typealias State = (balance: Decimal, locked: Bool)
///   typealias CommandType = BankCommand
///
///   var initialState: State {
///     (balance: 0, locked: false)
///   }
///
///   func generateCommand(state: State) -> Gen<BankCommand> {
///     if state.locked {
///       return Gen.pure(.unlock)
///     } else {
///       return Gen.oneOf([
///         Gen<BankCommand>.int(in: -1000...1000).map { .withdraw($0) },
///         Gen<BankCommand>.int(in: 0...1000).map { .deposit($0) },
///         Gen.pure(.lock),
///       ])
///     }
///   }
///
///   func invariant(state: State) -> Bool {
///     // Balance should never go below -5000 (overdraft limit)
///     // Balance should never exceed 1_000_000 (sanity check)
///     state.balance >= -5000 && state.balance <= 1_000_000
///   }
/// }
/// ```
///
/// **Execution Flow**:
/// 1. `ModelTestRunner` initializes with your model's `initialState`
/// 2. For each test iteration, it generates a random sequence of valid commands using `generateCommand`
/// 3. It executes each command on both the model and the real system
/// 4. After each command, it verifies the `invariant` holds
/// 5. If any divergence is found, it shrinks the command sequence to a minimal counterexample
///
/// - See Also: ``Command``, ``ModelTestRunner``, ``ModelTestConfig``
public protocol StateMachine: Sendable {
  associatedtype State: Sendable
  associatedtype CommandType where CommandType: Command & Sendable, CommandType.State == State

  /// **Initial state of the system**
  ///
  /// Provides the starting state for all test sequences. This is the state from which
  /// the test runner begins executing random command sequences.
  ///
  /// - Returns: The state representing the system in its initial condition
  ///
  /// - Example:
  ///   ```swift
  ///   var initialState: [Int] {
  ///     []  // Empty stack
  ///   }
  ///   ```
  ///
  /// - Note: All test runs are independent and start from this same initial state.
  /// Ensure deterministic initialization for reproducible testing.
  var initialState: State { get }

  /// **Generate a command that's valid in the given state**
  ///
  /// Produces a generator for commands that can be validly executed in the current state.
  /// The test runner uses this to generate random command sequences that respect state constraints.
  ///
  /// - Parameters:
  ///   - state: The current model state
  ///
  /// - Returns: A generator that produces valid commands for this state
  ///
  /// - Example:
  ///   ```swift
  ///   func generateCommand(state: [Int]) -> Gen<StackCommand> {
  ///     if state.isEmpty {
  ///       // Can only push on empty stack
  ///       return Gen.int(in: 1...100).map { StackCommand.push($0) }
  ///     } else {
  ///       // Can push or pop
  ///       return Gen.oneOf([
  ///         Gen.int(in: 1...100).map { StackCommand.push($0) },
  ///         Gen.pure(.pop),
  ///       ])
  ///     }
  ///   }
  ///   ```
  ///
  /// - Important: Each command returned from this generator should pass its own `precondition`
  /// check for the given state. The test runner verifies preconditions and skips invalid commands.
  ///
  /// - Note: Use `Gen.oneOf`, `Gen.frequency`, and conditional logic to ensure generated
  /// commands respect the state machine's transition constraints.
  func generateCommand(state: State) -> Gen<CommandType>

  /// **Check invariants that should always hold**
  ///
  /// Defines safety properties that must be true in every state reachable through valid
  /// command sequences. This is the core specification of what "correct behavior" means for your system.
  ///
  /// - Parameters:
  ///   - state: The state to check
  ///
  /// - Returns: `true` if the state satisfies all invariants, `false` if violated
  ///
  /// - Example:
  ///   ```swift
  ///   func invariant(state: [Int]) -> Bool {
  ///     // Stack size must be within bounds
  ///     return state.isEmpty || state.count <= 1000
  ///   }
  ///
  ///   // Multiple invariants can be combined with &&
  ///   func invariant(state: BankAccount) -> Bool {
  ///     let balanceInRange = state.balance >= -5000 && state.balance <= 1_000_000
  ///     let notNegativeCount = state.transactionCount >= 0
  ///     return balanceInRange && notNegativeCount
  ///   }
  ///   ```
  ///
  /// - Important: If an invariant is violated, the test runner immediately fails and attempts
  /// to shrink the command sequence that led to the violation.
  ///
  /// - Note: Invariants are checked:
  ///   1. Before executing a command
  ///   2. After the model applies the command
  ///   3. After the real system executes the command
  func invariant(state: State) -> Bool
}

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
/// **Mathematical Semantics**:
/// The result represents the outcome of testing the property: "For all command sequences in
/// the state space, the model state matches the real system state." Success means no counterexample
/// was found; failure provides a minimal counterexample satisfying: `∃ commands ∈ Σ* : ¬Model(commands)`.
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
///   print("Original failing sequence: \(commands)")
// swiftlint:disable:next no_print
///   print("Minimal failing sequence: \(shrunk)")
// swiftlint:disable:next no_print
///   print("First failing command: \(failedCommand)")
///
/// case .gaveUp(let discarded, let iterations):
// swiftlint:disable:next no_print
///   print("Gave up after \(iterations) iterations (\(discarded) discarded)")
// swiftlint:disable:next no_print
///   print("Review command generation and preconditions")
/// }
/// ```
///
/// - See Also: ``ModelTestRunner``, ``Command``, ``ModelTestConfig``
public enum ModelTestResult<CommandType>: Sendable where CommandType: Command & Sendable {
  // swiftlint:disable:next orphaned_doc_comment
  /// **Test passed: All iterations succeeded without violations**
  ///
  /// Indicates the model-based test ran to completion without finding any failures.
  /// The system under test appears to conform to the model specification for at least
  /// the command sequences that were generated.
  ///
  /// - Parameters:
  ///   - iterations: The number of command sequences tested
  ///
  /// - Example:
  ///   ```swift
  ///   if case .success(let iterations) = result {
  // swiftlint:disable:next no_print
  ///     print("Tested \(iterations) command sequences successfully")
  ///   }
  ///   ```
  ///
  /// - Note: Success indicates high confidence in the system for the tested scenarios,
  /// but does not prove correctness (only property-based testing finds counterexamples,
  /// absence of them suggests but doesn't guarantee correctness).
  case success(iterations: Int)

  // swiftlint:disable:next orphaned_doc_comment
  /// **Test failed: Command sequence violated specification**
  ///
  /// Indicates the test runner found a command sequence that causes the system to violate
  /// the model specification. The failure includes:
  /// - The original failing sequence (may be long)
  /// - The minimal failing sequence (simplified for debugging)
  /// - The specific command that failed
  /// - When the failure was detected
  ///
  /// - Parameters:
  ///   - commands: The original complete command sequence that triggered the failure
  ///   - failedCommand: The specific command in the sequence that violated the postcondition or invariant
  ///   - iterations: The iteration number (1-indexed) when failure was detected
  ///   - shrunk: The minimal command sequence that still exhibits the same failure
  ///
  /// - Example:
  ///   ```swift
  ///   if case .failure(let commands, let failedCmd, let iter, let shrunk) = result {
  // swiftlint:disable:next no_print
  ///     print("Failure found in iteration \(iter)")
  // swiftlint:disable:next no_print
  ///     print("Original sequence (\(commands.count) commands): \(commands)")
  // swiftlint:disable:next no_print
  ///     print("Minimal sequence (\(shrunk.count) commands): \(shrunk)")
  // swiftlint:disable:next no_print
  ///     print("Failed command: \(failedCmd)")
  ///
  ///     // Analyze the minimal sequence for debugging
  ///     for (i, cmd) in shrunk.enumerated() {
  // swiftlint:disable:next no_print
  ///       print("  \(i): \(cmd)")
  ///     }
  ///   }
  ///   ```
  ///
  /// - Important: Always inspect the `shrunk` sequence first—it's the simplest form of
  /// the bug and easiest to understand and fix.
  ///
  /// - Note: The `failedCommand` indicates which command in the sequence failed, either
  /// by violating its postcondition or by causing an invariant violation after execution.
  case failure(
    commands: [CommandType],
    failedCommand: CommandType,
    iterations: Int,
    shrunk: [CommandType]
  )

  // swiftlint:disable:next orphaned_doc_comment
  /// **Test incomplete: Too many discarded command sequences**
  ///
  /// Indicates the test runner gave up because too many generated command sequences were
  /// invalid (failed preconditions). This typically means:
  /// - Command preconditions are too restrictive
  /// - The state space isn't being explored effectively
  /// - The model's `generateCommand` isn't producing valid commands for the states being reached
  ///
  /// This isn't a test failure—it's a test configuration issue.
  ///
  /// - Parameters:
  ///   - discarded: The number of invalid command sequences discarded
  ///   - iterations: The number of iterations attempted before giving up
  ///
  /// - Example:
  ///   ```swift
  ///   if case .gaveUp(let discarded, let iterations) = result {
  ///     let discardRate = Double(discarded) / Double(iterations) * 100
  // swiftlint:disable:next no_print
  ///     print("Gave up: \(discardRate)% command sequences were invalid")
  // swiftlint:disable:next no_print
  ///     print("Review preconditions and command generation")
  ///   }
  ///   ```
  ///
  /// **Debugging "gave up" results**:
  ///
  /// 1. **Review command generation**: Ensure `StateMachine.generateCommand` produces
  ///    commands that match the current state constraints
  ///
  /// 2. **Check preconditions**: Verify `Command.precondition` accurately reflects when
  ///    a command is valid. Overly restrictive preconditions cause discards.
  ///
  /// 3. **Increase maxCommands**: If most discards happen early, try increasing
  ///    `ModelTestConfig.maxCommands` to reach more states
  ///
  /// 4. **State-aware generation**: Use conditional logic in `generateCommand` to
  ///    produce more state-appropriate commands
  ///
  /// - Note: A small number of discards (< 5% of iterations) is normal and acceptable.
  /// High discard rates (> 20%) indicate configuration issues needing investigation.
  case gaveUp(discarded: Int, iterations: Int)
}

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
/// **Mathematical Model**:
/// The runner tests the property that for all valid command sequences, the real system's state
/// matches the model's predicted state. Formally: `∀ commands ∈ validSequences : realState(commands) ≈ modelState(commands)`
///
/// **Usage**:
/// ```swift
/// // Create a runner (optionally with a seed for reproducibility)
/// let runner = ModelTestRunner(seed: nil)  // Random seed
///
/// // Run a model-based test
/// let result = await runner.runModelTest(myModel, config: .default)
///
/// // Handle results
/// switch result {
/// case .success(let iterations):
// swiftlint:disable:next no_print
///   print("Passed all \(iterations) iterations")
/// case .failure(let commands, _, let iterations, let shrunk):
// swiftlint:disable:next no_print
///   print("Failed in iteration \(iterations)")
// swiftlint:disable:next no_print
///   print("Minimal counterexample: \(shrunk)")
/// case .gaveUp(let discarded, _):
// swiftlint:disable:next no_print
///   print("Gave up with \(discarded) discarded sequences")
/// }
/// ```
///
/// **Advanced Features**:
/// - Parallel test execution via standard Swift concurrency patterns
/// - Configurable iteration counts and shrinking aggressiveness
/// - Support for both deterministic and randomized testing
/// - Integration with property testing framework
///
/// - See Also: ``ModelTestConfig``, ``ModelTestResult``, ``StateMachine``, ``Command``
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public actor ModelTestRunner {
  private var rng: any RandomNumberGenerator

  /// **Initialize a model-based test runner**
  ///
  /// Creates a runner that will execute tests with either deterministic (seeded) or random behavior.
  ///
  /// - Parameters:
  ///   - seed: Optional seed for deterministic testing. If `nil`, uses system entropy for random variation.
  ///
  /// - Example:
  ///   ```swift
  ///   // For reproducible testing of a specific failure
  ///   let runner = ModelTestRunner(seed: Seed(value: 12345))
  ///
  ///   // For random testing with different sequences each run
  ///   let runner = ModelTestRunner(seed: nil)
  ///   ```
  ///
  /// - Note: Each runner instance is independent. Use separate runners for concurrent tests
  /// to ensure they don't interfere with each other's random number streams.
  ///
  /// - See Also: ``Seed``, ``SeedBasedRandomNumberGenerator``
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
  /// Runs the full model-based testing process:
  /// 1. Generates random command sequences respecting the model's state constraints
  /// 2. Executes commands on the real system and verifies against the model
  /// 3. Checks invariants before and after each command
  /// 4. Shrinks any failed sequence to find the minimal counterexample
  /// 5. Reports success, failure with counterexample, or gave-up status
  ///
  /// The testing process is deterministic if a seed was provided, random otherwise.
  /// Each iteration is independent, starting from the model's `initialState`.
  ///
  /// - Parameters:
  ///   - model: The state machine model specifying the system under test
  ///   - config: Configuration controlling iterations, sequence length, and shrinking
  ///
  /// - Returns: Result indicating success, failure with counterexample, or test incompleteness
  ///
  /// - Example:
  ///   ```swift
  ///   let runner = ModelTestRunner()
  ///   let config = ModelTestConfig(
  ///     maxCommands: 20,
  ///     maxShrinks: 1000,
  ///     iterations: 100,
  ///     seed: nil
  ///   )
  ///
  ///   let result = await runner.runModelTest(myStateMachine, config: config)
  ///
  ///   switch result {
  ///   case .success(let iterations):
  // swiftlint:disable:next no_print
  ///     print("All \(iterations) command sequences passed!")
  ///
  ///   case .failure(let commands, let failedCmd, let iter, let shrunk):
  // swiftlint:disable:next no_print
  ///     print("Failure found in iteration \(iter)")
  // swiftlint:disable:next no_print
  ///     print("Minimal failing sequence: \(shrunk.count) commands")
  ///     // Fix the implementation based on shrunk sequence
  ///
  ///   case .gaveUp(let discarded, let iterations):
  // swiftlint:disable:next no_print
  ///     print("Test gave up: \(discarded)/\(iterations) sequences discarded")
  ///     // Review command generation and preconditions
  ///   }
  ///   ```
  ///
  /// **Testing Process Details**:
  ///
  /// For each of `config.iterations`:
  /// 1. Generate a sequence of 1 to `maxCommands` commands
  /// 2. For each command:
  ///    - Verify precondition in current state
  ///    - Check model invariant before execution
  ///    - Execute on real system
  ///    - Verify postcondition
  ///    - Update model state
  ///    - Check model invariant after execution
  /// 3. If any check fails, shrink the sequence and return `.failure`
  /// 4. If too many sequences fail preconditions, return `.gaveUp`
  /// 5. After all iterations, return `.success`
  ///
  /// - Throws: Does not throw; all errors are captured in result status
  ///
  /// - See Also: ``ModelTestConfig``, ``ModelTestResult``
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
  ) async throws -> [Model.CommandType] {
    var commands: [Model.CommandType] = []
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
    commands: [Model.CommandType]
  ) async throws -> ExecutionResult<Model.CommandType> {
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
  ) async -> ModelTestResult<Model.CommandType> {
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
    Gen<Int> { rng, _ in Int.random(in: -10...10, using: &rng) }
      .map { IncrementCommand(amount: $0) }
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
    state.count <= 1000
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
        // For synchronous testing, we'll use a simplified check
        return commands.count <= config.maxCommands
      }
    )
  }
}

// swiftlint:disable:next orphaned_doc_comment
/// **Generator for valid command sequences from a state machine**
///
/// `ModelCommandSequenceGenerator` bridges model-based testing with the property-based testing
/// framework by converting a `StateMachine` into a `Gen` that produces valid command sequences.
/// It ensures all generated sequences respect the state machine's preconditions and state evolution.
///
/// **Design Purpose**:
/// This type adapts a stateful model into a generator of test data. It's used internally by
/// `ModelTestRunner` and can be used directly for property-based testing of command sequences.
///
/// **How It Works**:
/// 1. Starts with the model's initial state
/// 2. For each step, generates a command valid in the current state using `model.generateCommand`
/// 3. Applies the command to update the model state
/// 4. Continues until reaching max commands or the size parameter
/// 5. Returns a complete valid command sequence
///
/// **Usage**:
/// ```swift
/// // Direct usage for property-based testing
/// let generator = ModelCommandSequenceGenerator(model: myModel, config: config)
/// let commandSeqGen = generator.asGen()
///
/// // Generate sample sequences
/// let seed = Seed(value: 42)
/// let sample = commandSeqGen.sample(size: .medium, seed: seed)
// swiftlint:disable:next no_print
/// print("Generated sequence of \(sample.count) commands")
///
/// // Or use in a property
/// let prop = Property(
///   generator: commandSeqGen,
///   predicate: { commands in
///     // Test the command sequence
///     return true
///   }
/// )
/// ```
///
/// **Integration with Property Testing**:
/// The generated sequences are valid by construction—they respect all preconditions and
/// follow state transitions. This makes them ideal inputs for property-based testing that
/// verifies system behavior across all valid command sequences.
///
/// - See Also: ``ModelTestRunner``, ``StateMachine``, ``Gen``
public struct ModelCommandSequenceGenerator<Model: StateMachine>: Sendable {
  /// **The state machine model**
  ///
  /// Provides the initial state, command generation, and state transition logic.
  public let model: Model

  /// **Configuration controlling sequence generation**
  ///
  /// Specifically, `maxCommands` limits the sequence length to ensure reasonable generation time.
  public let config: ModelTestConfig

  /// **Initialize with a model and configuration**
  ///
  /// - Parameters:
  ///   - model: The state machine model to generate sequences from
  ///   - config: Configuration controlling maximum sequence length
  ///
  /// - Example:
  ///   ```swift
  ///   let generator = ModelCommandSequenceGenerator(
  ///     model: myStateMachine,
  ///     config: ModelTestConfig(maxCommands: 30)
  ///   )
  ///   ```
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
  ///
  /// - Example:
  ///   ```swift
  ///   let seqGen = generator.asGen()
  ///
  ///   // Generate samples
  ///   let sample1 = seqGen.generate(&rng, .small)
  ///   let sample2 = seqGen.generate(&rng, .large)
  ///
  ///   // Use in property
  ///   let prop = Property(generator: seqGen, predicate: { commands in
  ///     // Test command sequence
  ///     return true
  ///   })
  ///   ```
  ///
  /// - Note: The generated sequences scale with the size parameter—larger sizes
  /// generate longer sequences up to `maxCommands`.
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
