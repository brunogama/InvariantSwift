/// RuleBasedStateMachine - Core types for rule-based stateful testing
///
/// Implements ISP-0003: Hypothesis-style stateful testing where rules define
/// valid operations, bundles accumulate values, and invariants are checked
/// after each step.

import Foundation

// MARK: - Core Protocol

/// Protocol for rule-based state machine tests.
///
/// Conforming types define rules (valid operations), invariants (properties
/// that must hold), and bundles (accumulated values).
///
/// **Usage:**
/// ```swift
/// @RuleBasedTest
/// struct CounterSpec: RuleBasedStateMachine {
///     var expected = 0
///     let counter = Counter()
///
///     @Rule
///     mutating func increment() {
///         counter.increment()
///         expected += 1
///     }
///
///     @Invariant
///     func valueMatches() -> Bool {
///         counter.value == expected
///     }
/// }
/// ```
public protocol RuleBasedStateMachine {
  /// The rules that can be executed on this state machine
  static var rules: [AnyRule<Self>] { get }

  /// Invariants that must hold after every rule execution
  static var invariants: [(String, (Self) -> Bool)] { get }

  /// Bundles for accumulating values across rules
  static var bundles: [AnyBundle<Self>] { get }

  /// Create initial state for testing
  init()

  /// Run the state machine test
  static func run(maxSteps: Int, maxExamples: Int) async throws
}

// Default implementations
extension RuleBasedStateMachine {
  public static var bundles: [AnyBundle<Self>] { [] }
}

// MARK: - Rule

/// A type-erased rule that can be executed on a state machine.
public struct AnyRule<State>: Sendable {
  /// Name of the rule for reporting
  public let name: String

  /// Weight for selection (higher = more likely)
  public let weight: Int

  /// Precondition that must be true for rule to be considered
  public let precondition: @Sendable (State) -> Bool

  /// Execute the rule on mutable state
  public let execute: @Sendable (inout State) throws -> Void

  /// Description generator for shrinking reports
  public let describe: @Sendable () -> String

  public init(
    name: String,
    weight: Int = 1,
    precondition: @escaping @Sendable (State) -> Bool = { _ in true },
    execute: @escaping @Sendable (inout State) throws -> Void,
    describe: @escaping @Sendable () -> String = { "" }
  ) {
    self.name = name
    self.weight = weight
    self.precondition = precondition
    self.execute = execute
    self.describe = describe
  }
}

// MARK: - Bundle

/// A type-erased bundle for accumulating values.
public struct AnyBundle<State>: Sendable {
  /// Name of the bundle
  public let name: String

  /// Get the current count of items in the bundle
  public let count: @Sendable (State) -> Int

  /// Check if the bundle is empty
  public let isEmpty: @Sendable (State) -> Bool

  public init(
    name: String,
    count: @escaping @Sendable (State) -> Int,
    isEmpty: @escaping @Sendable (State) -> Bool
  ) {
    self.name = name
    self.count = count
    self.isEmpty = isEmpty
  }
}

/// Reference to a value in a bundle.
///
/// Used in rule parameters to draw from accumulated values:
/// ```swift
/// @Rule
/// func read(key: BundleRef<String>) {
///     // key.value is drawn from the knownKeys bundle
/// }
/// ```
public struct BundleRef<T: Sendable>: Sendable {
  /// The actual value from the bundle
  public let value: T

  /// Index within the bundle
  public let index: Int

  public init(value: T, index: Int) {
    self.value = value
    self.index = index
  }
}

// Common type aliases
public typealias KeyRef = BundleRef<String>
public typealias ValueRef = BundleRef<Data>

// MARK: - Executed Step

/// Record of a single executed step for reporting and shrinking.
public struct ExecutedStep: Sendable, CustomStringConvertible {
  /// Name of the rule that was executed
  public let ruleName: String

  /// Description of the arguments used
  public let arguments: String

  /// Timestamp of execution
  public let timestamp: Date

  public init(ruleName: String, arguments: String = "", timestamp: Date = Date()) {
    self.ruleName = ruleName
    self.arguments = arguments
    self.timestamp = timestamp
  }

  public var description: String {
    if arguments.isEmpty {
      return ruleName
    } else {
      return "\(ruleName)(\(arguments))"
    }
  }
}

// MARK: - Test Result

/// Result of a rule-based test run.
public enum RuleBasedTestResult: Sendable {
  /// All examples passed
  case passed(examples: Int, totalSteps: Int)

  /// An invariant failed
  case invariantFailed(
    invariant: String,
    steps: [ExecutedStep],
    shrunkSteps: [ExecutedStep]?
  )

  /// A rule threw an error
  case ruleError(
    rule: String,
    error: String,
    steps: [ExecutedStep]
  )

  /// No valid rules could be found
  case noValidRules(afterSteps: Int)
}

// MARK: - State Machine Runner

/// Runner for executing rule-based state machine tests.
public actor RuleBasedTestRunner<State: RuleBasedStateMachine> {

  private let maxSteps: Int
  private let maxExamples: Int
  private let seed: UInt64?

  public init(maxSteps: Int = 100, maxExamples: Int = 100, seed: UInt64? = nil) {
    self.maxSteps = maxSteps
    self.maxExamples = maxExamples
    self.seed = seed
  }

  /// Run the state machine test
  public func run(initialState: @escaping () -> State) async -> RuleBasedTestResult {
    var totalSteps = 0
    var rng =
      seed.map { SeededRandomNumberGenerator(seed: $0) }
      ?? SeededRandomNumberGenerator(seed: UInt64.random(in: 0...UInt64.max))

    for _ in 0..<maxExamples {
      var state = initialState()
      var steps: [ExecutedStep] = []

      for _ in 0..<maxSteps {
        // Find valid rules
        let validRules = State.rules.filter { $0.precondition(state) }

        guard !validRules.isEmpty else {
          // No valid rules, end this example
          break
        }

        // Select a rule based on weight
        let rule = selectWeightedRule(validRules, rng: &rng)

        // Execute the rule
        let stepRecord = ExecutedStep(ruleName: rule.name, arguments: rule.describe())
        steps.append(stepRecord)
        totalSteps += 1

        do {
          try rule.execute(&state)
        } catch {
          return .ruleError(rule: rule.name, error: "\(error)", steps: steps)
        }

        // Check invariants
        for (invariantName, check) in State.invariants where !check(state) {
          // Try to shrink
          let shrunkSteps = shrinkSteps(
            steps: steps,
            initialState: initialState,
            failingInvariant: invariantName
          )

          return .invariantFailed(
            invariant: invariantName,
            steps: steps,
            shrunkSteps: shrunkSteps
          )
        }
      }
    }

    return .passed(examples: maxExamples, totalSteps: totalSteps)
  }

  /// Select a rule based on weights
  private func selectWeightedRule(
    _ rules: [AnyRule<State>],
    rng: inout SeededRandomNumberGenerator
  ) -> AnyRule<State> {
    let totalWeight = rules.reduce(0) { $0 + $1.weight }
    var selection = Int.random(in: 0..<totalWeight, using: &rng)

    for rule in rules {
      selection -= rule.weight
      if selection < 0 {
        return rule
      }
    }

    return rules.last!
  }

  /// Shrink the failing step sequence
  private func shrinkSteps(
    steps: [ExecutedStep],
    initialState: @escaping () -> State,
    failingInvariant: String
  ) -> [ExecutedStep]? {
    guard steps.count > 1 else { return nil }

    var bestSteps = steps

    // Try removing each step
    for i in (0..<steps.count).reversed() {
      var candidate = bestSteps
      candidate.remove(at: i)

      if reproduceFailure(steps: candidate, initialState: initialState, invariant: failingInvariant)
      {
        bestSteps = candidate
      }
    }

    return bestSteps.count < steps.count ? bestSteps : nil
  }

  /// Try to reproduce a failure with a given step sequence
  private func reproduceFailure(
    steps: [ExecutedStep],
    initialState: @escaping () -> State,
    invariant: String
  ) -> Bool {
    var state = initialState()

    for step in steps {
      guard let rule = State.rules.first(where: { $0.name == step.ruleName }) else {
        return false
      }

      guard rule.precondition(state) else {
        return false
      }

      do {
        try rule.execute(&state)
      } catch {
        return false
      }
    }

    // Check if the invariant still fails
    guard let (_, check) = State.invariants.first(where: { $0.0 == invariant }) else {
      return false
    }

    return !check(state)
  }
}

// MARK: - Seeded RNG

/// A seeded random number generator for reproducible tests.
public struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
  private var state: UInt64

  public init(seed: UInt64) {
    state = seed
  }

  public mutating func next() -> UInt64 {
    // xorshift64
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

// MARK: - Default Run Implementation

extension RuleBasedStateMachine where Self: Sendable {
  public static func run(maxSteps: Int = 100, maxExamples: Int = 100) async throws {
    let runner = RuleBasedTestRunner<Self>(maxSteps: maxSteps, maxExamples: maxExamples)
    let result = await runner.run { Self() }

    switch result {
    case .passed:
      // Test passed, nothing to report
      break

    case .invariantFailed(let invariant, let steps, let shrunkSteps):
      let finalSteps = shrunkSteps ?? steps
      var message = "Invariant '\(invariant)' failed after \(finalSteps.count) steps:\n"
      for (i, step) in finalSteps.enumerated() {
        message += "  \(i + 1). \(step)\n"
      }
      throw RuleBasedTestError.invariantViolation(message)

    case .ruleError(let rule, let error, let steps):
      throw RuleBasedTestError.ruleExecutionError(
        "Rule '\(rule)' threw error after \(steps.count) steps: \(error)"
      )

    case .noValidRules:
      // No valid rules to execute, test ends early but doesn't fail
      break
    }
  }
}

/// Errors from rule-based tests
public enum RuleBasedTestError: Error, CustomStringConvertible {
  case invariantViolation(String)
  case ruleExecutionError(String)

  public var description: String {
    switch self {
    case .invariantViolation(let msg): return msg
    case .ruleExecutionError(let msg): return msg
    }
  }
}
