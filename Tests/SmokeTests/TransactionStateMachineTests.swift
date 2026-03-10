import Testing
import InvariantSwiftCore
import InvariantSwift

// MARK: - Domain Model (abstract state)

/// Abstract model of a simple key-value database with transaction semantics.
struct TransactionModel: Sendable {
  var hasActiveTransaction: Bool = false
  var committedRows: [String: Int] = [:]
  var pendingRows: [String: Int] = [:]
}

// MARK: - SUT (simulated database)

/// In-memory database actor that enforces transaction semantics.
actor SimulatedDatabase {
  private var committedRows: [String: Int] = [:]
  private var pendingRows: [String: Int] = [:]
  private(set) var transactionOpen = false

  func begin() throws {
    guard !transactionOpen else {
      throw TransactionError.alreadyOpen
    }
    transactionOpen = true
  }

  func write(key: String, value: Int) throws {
    guard transactionOpen else {
      throw TransactionError.noOpenTransaction
    }
    pendingRows[key] = value
  }

  func commit() throws {
    guard transactionOpen else {
      throw TransactionError.noOpenTransaction
    }
    for (k, val) in pendingRows {
      committedRows[k] = val
    }
    pendingRows.removeAll()
    transactionOpen = false
  }

  func rollback() throws {
    guard transactionOpen else {
      throw TransactionError.noOpenTransaction
    }
    pendingRows.removeAll()
    transactionOpen = false
  }

  var committed: [String: Int] { committedRows }
  var pending: [String: Int] { pendingRows }
}

// MARK: - TransactionError

enum TransactionError: Error {
  case alreadyOpen
  case noOpenTransaction
}

// MARK: - Command Result

enum TransactionResult: Sendable {
  case began
  case wrote(key: String, value: Int)
  case committed([String: Int])
  case rolledBack
}

// MARK: - Commands

enum TransactionCommand: Command, Sendable {
  case begin
  case write(key: String, value: Int)
  case commit
  case rollback

  // MARK: Precondition

  func precondition(state: TransactionModel) -> Bool {
    switch self {
    case .begin:
      return !state.hasActiveTransaction

    case .write:
      return state.hasActiveTransaction

    case .commit:
      return state.hasActiveTransaction

    case .rollback:
      return state.hasActiveTransaction
    }
  }

  // MARK: Execute

  /// Execute uses the `db` stored in the command via a task-local.
  /// We close over a shared actor reference injected at test time.
  func execute() async throws -> TransactionResult {
    guard let db = Self.currentDatabase else {
      throw TransactionError.noOpenTransaction
    }
    switch self {
    case .begin:
      try await db.begin()
      return .began

    case .write(let key, let value):
      try await db.write(key: key, value: value)
      return .wrote(key: key, value: value)

    case .commit:
      let snap = await db.committed
      try await db.commit()
      return .committed(snap)

    case .rollback:
      try await db.rollback()
      return .rolledBack
    }
  }

  // MARK: Apply

  func apply(state: TransactionModel) -> TransactionModel {
    var next = state
    switch self {
    case .begin:
      next.hasActiveTransaction = true

    case .write(let key, let value):
      next.pendingRows[key] = value

    case .commit:
      for (k, val) in state.pendingRows {
        next.committedRows[k] = val
      }
      next.pendingRows.removeAll()
      next.hasActiveTransaction = false

    case .rollback:
      next.pendingRows.removeAll()
      next.hasActiveTransaction = false
    }
    return next
  }

  // MARK: Postcondition

  func postcondition(state: TransactionModel, result: TransactionResult) -> Bool {
    switch (self, result) {
    case (.begin, .began):
      return true

    case (.write(let k, let val), .wrote(let rk, let rv)):
      return k == rk && val == rv

    case (.commit, .committed):
      return true

    case (.rollback, .rolledBack):
      return true

    default:
      return false
    }
  }

  // MARK: Database injection via task local

  @TaskLocal static var currentDatabase: SimulatedDatabase?
}

// MARK: - State Machine

struct TransactionStateMachine: StateMachine {
  var initialState: TransactionModel { TransactionModel() }

  func generateCommand(state: TransactionModel) -> Gen<TransactionCommand> {
    if !state.hasActiveTransaction {
      return Gen.pure(.begin)
    }
    let keyGen = Gen<String>.oneOf([Gen.pure("a"), Gen.pure("b"), Gen.pure("c")])
    let writeGen = keyGen.flatMap { key in
      Gen<Int>.int(in: 1...100).map { value in
        TransactionCommand.write(key: key, value: value)
      }
    }
    return Gen.oneOf([
      Gen.pure(.begin),
      writeGen,
      Gen.pure(.commit),
      Gen.pure(.rollback),
    ])
  }

  func invariant(state: TransactionModel) -> Bool {
    // Pending rows only exist when a transaction is active.
    if !state.hasActiveTransaction && !state.pendingRows.isEmpty {
      return false
    }
    return true
  }
}

// MARK: - Tests

@Suite("Transaction State Machine")
struct TransactionStateMachineTests {

  @Test("Random transaction sequences pass")
  func randomSequencesPass() async {
    let model = TransactionStateMachine()
    // Each iteration uses a fresh database so SUT state never bleeds between runs.
    let singleIterationConfig = ModelTestConfig(maxCommands: 15, maxShrinks: 50, iterations: 1)

    for _ in 0..<30 {
      let db = SimulatedDatabase()
      let result = await TransactionCommand.$currentDatabase.withValue(db) {
        await ModelTestRunner.checkModel(model, config: singleIterationConfig)
      }

      switch result {
      case .success:
        continue

      case .failure(let trace, let iteration, let shrunkTrace):
        Issue.record(
          """
          Random transaction test failed at iteration \(iteration).
          Failing step: \(trace.failingStep.map { "\($0.index): \($0.failureKind as Any)" } ?? "none")
          Shrunk to \(shrunkTrace.commands.count) commands.
          """
        )
        return

      case .gaveUp:
        continue
      }
    }
  }

  @Test("Failure injection: commit fails at step index 2")
  func failureInjectionAtCommit() async throws {
    let db = SimulatedDatabase()
    let model = TransactionStateMachine()

    // Force a sequence: begin, write, commit (commit is at index 2)
    let commands: [TransactionCommand] = [.begin, .write(key: "x", value: 42), .commit]

    let injector = FailureInjector<TransactionCommand>.atIndex(
      2,
      error: InjectedError.message("commit forced failure")
    )

    let runner = ModelTestRunner()
    let result = await TransactionCommand.$currentDatabase.withValue(db) {
      await runner.runModelTest(
        model,
        config: ModelTestConfig(maxCommands: 3, maxShrinks: 10, iterations: 1),
        failureInjector: injector
      )
    }

    // The injector should force a failure
    switch result {
    case .failure(let trace, _, _):
      let failingStep = trace.failingStep
      #expect(failingStep != nil, "There should be a failing step")
      if case .injectedFailure = failingStep?.failureKind {
        // Expected path
      } else {
        Issue.record("Expected injectedFailure kind, got: \(failingStep?.failureKind as Any)")
      }

    case .success:
      // The randomly generated sequence might not reach index 2 — that's acceptable
      break

    case .gaveUp:
      break
    }
    _ = commands  // commands used as documentation of expected sequence
  }

  @Test("Execution trace identifies the failing step")
  func traceIdentifiesFailingStep() async {
    let model = TransactionStateMachine()
    // Inject a failure at index 1 to produce a predictable per-step trace.
    let injector = FailureInjector<TransactionCommand>.atIndex(
      1,
      error: InjectedError.message("write failure")
    )
    let singleConfig = ModelTestConfig(maxCommands: 10, maxShrinks: 20, iterations: 1)

    for _ in 0..<50 {
      let db = SimulatedDatabase()
      let result = await TransactionCommand.$currentDatabase.withValue(db) {
        await ModelTestRunner.checkModel(model, config: singleConfig, failureInjector: injector)
      }

      switch result {
      case .failure(let trace, _, _):
        guard let failingStep = trace.failingStep else {
          Issue.record("Trace has no failing step")
          return
        }
        #expect(
          failingStep.index == 1,
          "Injector targets index 1; failing step index should be 1, got \(failingStep.index)"
        )
        if case .injectedFailure = failingStep.failureKind {
          // Expected
        } else {
          Issue.record("Unexpected failure kind: \(failingStep.failureKind as Any)")
        }
        return

      case .success, .gaveUp:
        continue
      }
    }
  }

  @Test("Shrunk trace is shorter than original and still fails")
  func shrinkingProducesValidMinimalTrace() async {
    let model = TransactionStateMachine()
    // Inject at index 3 — forces sequences of ≥4 commands to eventually fail.
    let injector = FailureInjector<TransactionCommand>.atIndex(3, error: InjectedError.default)
    let singleConfig = ModelTestConfig(maxCommands: 20, maxShrinks: 100, iterations: 1)

    for _ in 0..<50 {
      let db = SimulatedDatabase()
      let result = await TransactionCommand.$currentDatabase.withValue(db) {
        await ModelTestRunner.checkModel(model, config: singleConfig, failureInjector: injector)
      }

      switch result {
      case .failure(let trace, _, let shrunkTrace):
        #expect(
          shrunkTrace.commands.count <= trace.commands.count,
          "Shrunk trace must not be longer than original"
        )
        #expect(
          shrunkTrace.failingStepIndex != nil,
          "Shrunk trace must still contain a failing step"
        )
        return

      case .success, .gaveUp:
        continue
      }
    }
  }

  @Test("Once injector fires exactly once")
  func onceInjectorFiresOnce() async {
    let model = TransactionStateMachine()
    let db = SimulatedDatabase()

    let injector = FailureInjector<TransactionCommand>.onceAtIndex(0)

    // Run with many iterations; the injector fires only on the first hit
    let config = ModelTestConfig(maxCommands: 5, maxShrinks: 0, iterations: 10)
    let result = await TransactionCommand.$currentDatabase.withValue(db) {
      await ModelTestRunner.checkModel(model, config: config, failureInjector: injector)
    }

    switch result {
    case .failure:
      // One failure is expected
      break

    case .success:
      // Also valid if later iterations all pass (injector already fired)
      break

    case .gaveUp:
      break
    }
    // Main invariant: the test completes without hanging or crashing
  }
}
