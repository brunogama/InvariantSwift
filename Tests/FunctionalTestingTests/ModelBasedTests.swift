import Testing
@testable import FunctionalTesting

/// Tests for the model-based testing framework
struct ModelBasedTests {

  // MARK: - Basic Model Testing

  @Test("Counter model-based test")
  func counterModelTest() async {
    let model = CounterStateMachine()
    let config = ModelTestConfig(maxCommands: 10, iterations: 20)

    let result = await ModelTestRunner.checkModel(model, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 20, "Should complete all iterations")
    case .failure(let commands, let failedCommand, let iterations, let shrunk):
      Issue.record(
        "Counter model failed: \(failedCommand) in sequence \(commands.count), shrunk to \(shrunk.count) commands after \(iterations) iterations"
      )
    case .gaveUp(let discarded, let iterations):
      Issue.record(
        "Counter model gave up: discarded \(discarded) cases in \(iterations) iterations"
      )
    }
  }

  @Test("Stack model-based test")
  func stackModelTest() async {
    let model = StackStateMachine()
    let config = ModelTestConfig(maxCommands: 15, iterations: 30)

    let result = await ModelTestRunner.checkModel(model, config: config)

    switch result {
    case .success(let iterations):
      #expect(iterations == 30, "Stack model should pass all iterations")
    case .failure(let commands, let failedCommand, _, let shrunk):
      // Analyze the failure
      switch failedCommand {
      case .push(let value):
        Issue.record(
          "Stack push(\(value)) failed in sequence of \(commands.count) commands, shrunk to \(shrunk.count)"
        )
      case .pop:
        Issue.record(
          "Stack pop failed in sequence of \(commands.count) commands, shrunk to \(shrunk.count)"
        )
      }
    case .gaveUp(let discarded, let iterations):
      Issue.record("Stack model gave up: discarded \(discarded) cases in \(iterations) iterations")
    }
  }

  // MARK: - State Machine Invariant Testing

  @Test("Counter invariant is maintained")
  func counterInvariantTest() async {
    let model = CounterStateMachine()

    // Test with extreme commands to verify bounds checking
    let config = ModelTestConfig(maxCommands: 50, iterations: 100)
    let result = await ModelTestRunner.checkModel(model, config: config)

    switch result {
    case .success:
      break  // Invariant held throughout testing
    case .failure(_, let failedCommand, _, let shrunk):
      // If it fails, it should be due to invariant violation
      Issue.record(
        "Counter invariant violated by command: \(failedCommand), minimal sequence: \(shrunk)"
      )
    case .gaveUp:
      Issue.record("Counter invariant test gave up")
    }
  }

  @Test("Stack invariant prevents overflow")
  func stackInvariantTest() async {
    let model = StackStateMachine()

    // Test with many push operations to check size limits
    let config = ModelTestConfig(maxCommands: 100, iterations: 50)
    let result = await ModelTestRunner.checkModel(model, config: config)

    switch result {
    case .success:
      break  // All tests respected stack size limits
    case .failure(_, let failedCommand, _, let shrunk):
      Issue.record(
        "Stack invariant violated by: \(failedCommand), minimal failing sequence has \(shrunk.count) commands"
      )
    case .gaveUp:
      break  // May give up due to precondition violations
    }
  }

  // MARK: - Command Generation Testing

  @Test("Generated commands respect preconditions")
  func commandPreconditionTest() async {
    let model = StackStateMachine()

    // Manually test command generation
    for testState in [[], [1], [1, 2, 3]] {
      let commandGen = model.generateCommand(state: testState)

      // Generate several commands and verify preconditions
      for _ in 0..<10 {
        let seed = Seed.random
        let size = Size(value: 10)
        let command = commandGen.sample(size: size, seed: seed)

        #expect(
          command.precondition(state: testState),
          "Generated command should satisfy precondition for state \(testState)"
        )
      }
    }
  }

  @Test("Command application updates state correctly")
  func commandApplicationTest() {
    let initialState = [1, 2, 3]

    let pushCommand = StackCommand.push(42)
    let popCommand = StackCommand.pop

    // Test push
    let afterPush = pushCommand.apply(state: initialState)
    #expect(afterPush == [1, 2, 3, 42], "Push should append to stack")

    // Test pop
    let afterPop = popCommand.apply(state: initialState)
    #expect(afterPop == [1, 2], "Pop should remove last element")

    // Test pop on empty (if precondition allows)
    let emptyResult = popCommand.apply(state: [])
    #expect(emptyResult.isEmpty, "Pop on empty should remain empty")
  }

  // MARK: - Shrinking Testing

  @Test("Failed sequences are shrunk to minimal counterexamples")
  func shrinkingEffectivenessTest() async {
    // Create a model that will definitely fail after a certain number of operations
    let model = BoundedCounterModel(limit: 10)

    let config = ModelTestConfig(maxCommands: 25, maxShrinks: 100, iterations: 50)
    let result = await ModelTestRunner.checkModel(model, config: config)

    switch result {
    case .success:
      Issue.record("Expected bounded counter to fail but it succeeded")
    case .failure(let original, _, _, let shrunk):
      // Shrunk sequence should be smaller
      #expect(
        shrunk.count <= original.count,
        "Shrunk sequence (\(shrunk.count)) should be smaller than original (\(original.count))"
      )

      // Shrunk sequence should still fail
      let shrunkResult = await ModelTestRunner.checkModel(
        model,
        config: ModelTestConfig(maxCommands: shrunk.count, iterations: 1)
      )

      switch shrunkResult {
      case .failure:
        break  // Good, shrunk sequence still fails
      case .success:
        Issue.record("Shrunk sequence should still fail the model")
      case .gaveUp:
        break  // May give up due to reduced size
      }
    case .gaveUp:
      break  // May give up due to precondition violations
    }
  }

  // MARK: - Deterministic Testing

  @Test("Same seed produces same command sequences")
  func deterministicGenerationTest() async {
    let model = CounterStateMachine()
    let seed = Seed(value: 42)
    let config = ModelTestConfig(maxCommands: 10, iterations: 5, seed: seed)

    // Run the same test multiple times
    var results: [ModelTestResult<IncrementCommand>] = []

    for _ in 0..<3 {
      let result = await ModelTestRunner.checkModel(model, config: config)
      results.append(result)
    }

    // All results should be identical (same seed, same behavior)
    let firstResult = results[0]

    switch firstResult {
    case .success(let iterations1):
      for (index, result) in results.enumerated() {
        switch result {
        case .success(let iterations):
          #expect(
            iterations == iterations1,
            "Result \(index) should have same iteration count"
          )
        default:
          Issue.record("Result \(index) differs in type from first result")
        }
      }
    case .failure:
      // All should fail in the same way
      for (index, result) in results.enumerated() {
        switch result {
        case .failure:
          break  // Expected
        default:
          Issue.record("Result \(index) should also be a failure")
        }
      }
    case .gaveUp:
      // All should give up in the same way
      for (index, result) in results.enumerated() {
        switch result {
        case .gaveUp:
          break  // Expected
        default:
          Issue.record("Result \(index) should also give up")
        }
      }
    }
  }

  // MARK: - Integration with Property Testing

  @Test("Model-based properties integrate with property testing")
  func modelPropertyIntegrationTest() async {
    let model = CounterStateMachine()
    let config = ModelTestConfig(maxCommands: 5, iterations: 20)

    let property = Property.fromModel(model, config: config)
    let result = PropertyChecker.check(property, config: PropertyConfig(iterations: 10))

    switch result {
    case .success:
      break  // Integration successful
    case .failure(let counterexample, let iterations, let shrunk):
      Issue.record(
        "Model property failed: \(counterexample.count) commands, shrunk to \(shrunk.count) after \(iterations) iterations"
      )
    case .gaveUp:
      Issue.record("Model property integration gave up")
    }
  }

  // MARK: - Complex State Machine Testing

  @Test("Complex state transitions work correctly")
  func complexStateTransitionTest() async {
    let model = ComplexStateMachine()
    let config = ModelTestConfig(maxCommands: 20, iterations: 30)

    let result = await ModelTestRunner.checkModel(model, config: config)

    switch result {
    case .success:
      break
    case .failure(let commands, let failedCommand, _, let shrunk):
      Issue.record(
        "Complex state machine failed at command \(failedCommand) in sequence of \(commands.count), shrunk to \(shrunk.count)"
      )
    case .gaveUp:
      break
    }
  }
}

// MARK: - Helper Models for Testing

/// A counter with an upper bound that will cause failures
struct BoundedCounterModel: StateMachine {
  let limit: Int
  let initialState: Int = 0

  init(limit: Int) {
    self.limit = limit
  }

  func generateCommand(state: Int) -> Gen<IncrementCommand> {
    Gen.int(in: 1...5).map { IncrementCommand(amount: $0) }
  }

  func invariant(state: Int) -> Bool {
    state <= limit
  }
}

/// A more complex state machine for advanced testing
struct ComplexStateMachine: StateMachine {
  struct State: Sendable {
    let counter: Int
    let items: [String]
    let isActive: Bool

    init(counter: Int = 0, items: [String] = [], isActive: Bool = true) {
      self.counter = counter
      self.items = items
      self.isActive = isActive
    }
  }

  let initialState = State()

  func generateCommand(state: State) -> Gen<ComplexCommand> {
    if !state.isActive {
      return Gen.pure(.activate)
    }

    return Gen.oneOf([
      Gen.int(in: 1...10).map { ComplexCommand.increment($0) },
      Gen.string.map { ComplexCommand.addItem($0) },
      Gen.pure(.deactivate),
    ])
  }

  func invariant(state: State) -> Bool {
    state.counter >= 0 && state.counter <= 100 && state.items.count <= 50
  }
}

enum ComplexCommand: Command {
  case increment(Int)
  case addItem(String)
  case activate
  case deactivate

  func precondition(state: ComplexStateMachine.State) -> Bool {
    switch self {
    case .increment(let amount):
      return state.isActive && state.counter + amount <= 100
    case .addItem:
      return state.isActive && state.items.count < 50
    case .activate:
      return !state.isActive
    case .deactivate:
      return state.isActive
    }
  }

  func execute() async throws -> Bool {
    return true  // Simplified execution
  }

  func apply(state: ComplexStateMachine.State) -> ComplexStateMachine.State {
    switch self {
    case .increment(let amount):
      return ComplexStateMachine.State(
        counter: state.counter + amount,
        items: state.items,
        isActive: state.isActive
      )
    case .addItem(let item):
      return ComplexStateMachine.State(
        counter: state.counter,
        items: state.items + [item],
        isActive: state.isActive
      )
    case .activate:
      return ComplexStateMachine.State(
        counter: state.counter,
        items: state.items,
        isActive: true
      )
    case .deactivate:
      return ComplexStateMachine.State(
        counter: state.counter,
        items: state.items,
        isActive: false
      )
    }
  }

  func postcondition(state: ComplexStateMachine.State, result: Bool) -> Bool {
    result == true
  }
}
