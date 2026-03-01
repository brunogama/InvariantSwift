import Foundation

// MARK: - Command Protocol

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

// MARK: - StateMachine Protocol

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

// MARK: - Built-in Command Types

/// **A command that modifies a simple integer counter**
///
/// Used for testing and demonstration of the model-based testing framework.
/// Increments or decrements a counter value within safe bounds.
///
/// - See Also: ``CounterStateMachine``
public struct IncrementCommand: Command {
  /// The amount to increment (positive) or decrement (negative)
  public let amount: Int

  /// Initialize with increment amount
  public init(amount: Int) {
    self.amount = amount
  }

  public func precondition(state: Int) -> Bool {
    state + amount <= 1000 && state + amount >= -1000
  }

  public func execute() async throws -> Int {
    amount
  }

  public func apply(state: Int) -> Int {
    state + amount
  }

  public func postcondition(state: Int, result: Int) -> Bool {
    result == amount
  }
}

/// **A simple counter state machine for testing**
///
/// Demonstrates how to implement `StateMachine` for a basic integer counter.
/// The counter maintains an integer value that can be incremented or decremented
/// within the range [-1000, 1000].
///
/// - See Also: ``IncrementCommand``, ``StateMachine``
public struct CounterStateMachine: StateMachine {
  public let initialState: Int = 0

  /// Initialize a counter state machine
  public init() {}

  public func generateCommand(state: Int) -> Gen<IncrementCommand> {
    Gen<Int> { rng, _ in Int.random(in: -10...10, using: &rng) }
      .map { IncrementCommand(amount: $0) }
  }

  public func invariant(state: Int) -> Bool {
    state >= -1000 && state <= 1000
  }
}

/// **Command that can fail probabilistically**
///
/// A test command that succeeds or fails based on a probability. Useful for testing
/// how the model-based testing framework handles flaky commands and retry scenarios.
///
/// - See Also: ``Command``, ``ModelTestError``
public struct FlakyCommand: Command {
  /// Probability of success (0.0 = always fail, 1.0 = always succeed)
  public let successProbability: Double

  /// The string value associated with this command
  public let value: String

  /// Initialize with success probability and value
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

/// **Stack-based state machine for testing**
///
/// Implements a simple stack model for demonstrating model-based testing with
/// push and pop operations. Maintains a stack with a maximum depth of 1000.
///
/// - See Also: ``StackCommand``, ``StackResult``, ``StateMachine``
public struct StackStateMachine: StateMachine {
  public let initialState: [Int] = []

  /// Initialize a stack state machine
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

/// **Commands for stack operations**
///
/// Represents the valid operations on a stack-based state machine.
/// Used with ``StackStateMachine`` to test push/pop command sequences.
///
/// - See Also: ``StackStateMachine``, ``StackResult``
public enum StackCommand: Command {
  /// Push a value onto the stack
  case push(Int)
  /// Pop the top value from the stack
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

/// **Result type for stack operations**
///
/// Represents the outcome of executing a ``StackCommand``.
///
/// - See Also: ``StackCommand``
public enum StackResult: Sendable {
  /// A value was pushed onto the stack
  case pushed(Int)
  /// The top value was popped from the stack
  case popped
}
