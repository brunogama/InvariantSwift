/// LinearizabilityTests - Comprehensive tests for linearizability checking
///
/// Verifies ThreadID, OperationContext, Operation, Spec, HBGraph,
/// LinearizabilityChecker, and built-in specifications.

import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

@Suite("Linearizability Checking")
struct LinearizabilityTests {

  // MARK: - ThreadID Tests

  @Test("ThreadID initialization and description")
  func testThreadIDBasics() {
    let threadId = ThreadID(42)
    #expect(threadId.value == 42)
    #expect(threadId.description.contains("42"))
  }

  @Test("ThreadID hashable conformance")
  func testThreadIDHashable() {
    let id1 = ThreadID(1)
    let id2 = ThreadID(1)
    let id3 = ThreadID(2)

    #expect(id1 == id2)
    #expect(id1 != id3)

    let set: Set<ThreadID> = [id1, id2, id3]
    #expect(set.count == 2)
  }

  // MARK: - OperationContext Tests

  @Test("OperationContext initialization")
  func testOperationContextInit() {
    let context = OperationContext(
      processId: 1,
      threadId: ThreadID(42),
      operationName: "push",
      metadata: ["key": "value"]
    )

    #expect(context.processId == 1)
    #expect(context.threadId.value == 42)
    #expect(context.operationName == "push")
    #expect(context.metadata["key"] == "value")
  }

  // MARK: - Operation Tests

  @Test("Operation stores call and response")
  func testOperationBasics() {
    let now = ContinuousClock().now
    let op = Operation<Int, Int>(
      call: 5,
      response: 10,
      startTime: now,
      endTime: now + .milliseconds(100),
      threadId: ThreadID(1),
      context: OperationContext(threadId: ThreadID(1), operationName: "double")
    )

    #expect(op.call == 5)
    #expect(op.response == 10)
  }

  @Test("Operation duration calculation")
  func testOperationDuration() {
    let now = ContinuousClock().now
    let op = Operation<String, String>(
      call: "input",
      response: "output",
      startTime: now,
      endTime: now + .seconds(1),
      threadId: ThreadID(1),
      context: OperationContext(threadId: ThreadID(1), operationName: "test")
    )

    // Duration should be approximately 1 second
    #expect(op.duration >= .seconds(1))
  }

  @Test("Operation overlaps detection")
  func testOperationOverlaps() {
    let now = ContinuousClock().now

    // Op1: [0, 100ms]
    let op1 = makeOperation(start: now, end: now + .milliseconds(100), call: 1)

    // Op2: [50ms, 150ms] - overlaps with op1
    let op2 = makeOperation(start: now + .milliseconds(50), end: now + .milliseconds(150), call: 2)

    // Op3: [200ms, 300ms] - doesn't overlap with op1
    let op3 = makeOperation(start: now + .milliseconds(200), end: now + .milliseconds(300), call: 3)

    #expect(op1.overlaps(with: op2))
    #expect(!op1.overlaps(with: op3))
  }

  @Test("Operation happens-before detection")
  func testOperationHappensBefore() {
    let now = ContinuousClock().now

    // Op1 ends before op2 starts
    let op1 = makeOperation(start: now, end: now + .milliseconds(100), call: 1)
    let op2 = makeOperation(start: now + .milliseconds(200), end: now + .milliseconds(300), call: 2)

    #expect(op1.happensBefore(op2))
    #expect(!op2.happensBefore(op1))
  }

  // MARK: - AnyOperation Tests

  @Test("AnyOperation type erasure")
  func testAnyOperationTypeErasure() {
    let now = ContinuousClock().now
    let op = Operation<Int, String>(
      call: 42,
      response: "result",
      startTime: now,
      endTime: now + .seconds(1),
      threadId: ThreadID(1),
      context: OperationContext(threadId: ThreadID(1), operationName: "process")
    )

    let anyOp = AnyOperation(from: op)

    #expect(anyOp.id == op.id)
    #expect(anyOp.operationName == "process")
    #expect(anyOp.description.contains("42"))
    #expect(anyOp.description.contains("result"))
  }

  // MARK: - Spec Tests

  @Test("Spec apply function works")
  func testSpecApply() {
    let spec = Spec<Int, Int, Int>(
      apply: { state, input in
        let old = state
        state += input
        return old
      }
    )

    var state = 10
    let result = spec.apply(&state, 5)

    #expect(result == 10)
    #expect(state == 15)
  }

  @Test("Spec precondition check")
  func testSpecPrecondition() {
    let spec = Spec<Int, Int, Int>(
      apply: { state, input in
        let old = state
        state += input
        return old
      },
      precondition: { state, input in
        state >= 0 && input >= 0
      }
    )

    #expect(spec.precondition(10, 5))
    #expect(!spec.precondition(-1, 5))
    #expect(!spec.precondition(10, -1))
  }

  // MARK: - CheckerConfig Tests

  @Test("CheckerConfig defaults")
  func testCheckerConfigDefaults() {
    let config = CheckerConfig()

    #expect(config.maxSearchSteps == 100000)
    #expect(!config.debugMode)
    #expect(config.enableOptimizations)
  }

  @Test("CheckerConfig fast preset")
  func testCheckerConfigFast() {
    let config = CheckerConfig.fast

    #expect(config.maxSearchSteps == 10000)
    #expect(config.enableOptimizations)
  }

  @Test("CheckerConfig thorough preset")
  func testCheckerConfigThorough() {
    let config = CheckerConfig.thorough

    #expect(config.maxSearchSteps == 1_000_000)
    #expect(config.debugMode)
  }

  // MARK: - StateFingerprint Tests

  @Test("StateFingerprint equality for same state")
  func testStateFingerprintEquality() {
    let ops = [UUID(), UUID()]
    let fp1 = StateFingerprint(state: 42, executedOps: ops)
    let fp2 = StateFingerprint(state: 42, executedOps: ops)

    #expect(fp1 == fp2)
  }

  // MARK: - SearchState Tests

  @Test("SearchState initialization")
  func testSearchStateInit() {
    let opIds: Set<UUID> = [UUID(), UUID()]
    let state = SearchState(
      remainingOps: opIds,
      currentState: 0,
      executedSequence: []
    )

    #expect(state.remainingOps.count == 2)
    #expect(state.depth == 0)
    #expect(!state.isComplete)
  }

  @Test("SearchState completion check")
  func testSearchStateComplete() {
    let state = SearchState<Int>(
      remainingOps: [],
      currentState: 42,
      executedSequence: [UUID()]
    )

    #expect(state.isComplete)
  }

  // MARK: - HBEdge Tests

  @Test("HBEdge initialization")
  func testHBEdgeInit() {
    let id1 = UUID()
    let id2 = UUID()
    let edge = HBEdge(from: id1, to: id2)

    #expect(edge.from == id1)
    #expect(edge.to == id2)
  }

  @Test("HBEdge hashable conformance")
  func testHBEdgeHashable() {
    let id1 = UUID()
    let id2 = UUID()

    let edge1 = HBEdge(from: id1, to: id2)
    let edge2 = HBEdge(from: id1, to: id2)

    #expect(edge1 == edge2)
  }

  // MARK: - HBGraph Tests

  @Test("HBGraph construction from operations")
  func testHBGraphConstruction() {
    let now = ContinuousClock().now

    let op1 = makeOperation(start: now, end: now + .milliseconds(50), call: 1)
    let op2 = makeOperation(start: now + .milliseconds(100), end: now + .milliseconds(150), call: 2)

    let graph: HBGraph<Int, Int> = HBGraph(operations: [op1, op2])

    #expect(graph.operations.count == 2)
    #expect(graph.happensBefore(op1.id, op2.id))
    #expect(!graph.happensBefore(op2.id, op1.id))
  }

  // MARK: - VerificationStep Tests

  @Test("VerificationStep stores details")
  func testVerificationStep() {
    let opId = UUID()
    let step = VerificationStep(
      operationId: opId,
      description: "push(5) -> void",
      stateBeforeJSON: "[1,2,3]",
      stateAfterJSON: "[1,2,3,5]"
    )

    #expect(step.operationId == opId)
    #expect(step.description.contains("push"))
  }

  // MARK: - PartialAnalysis Tests

  @Test("PartialAnalysis stores metrics")
  func testPartialAnalysis() {
    let analysis = PartialAnalysis(
      searchedStates: 1000,
      maxDepthReached: 10,
      timeElapsed: .seconds(5)
    )

    #expect(analysis.searchedStates == 1000)
    #expect(analysis.maxDepthReached == 10)
  }

  // MARK: - LinearizabilityResult Tests

  @Test("LinearizabilityResult linearizable case")
  func testResultLinearizable() {
    let witness = LinearizationWitness(
      sequentialOrder: [UUID()],
      finalState: "final",
      verificationSteps: []
    )

    let result = LinearizabilityResult.linearizable(witness: witness)
    #expect(result.isLinearizable)
  }

  @Test("LinearizabilityResult notLinearizable case")
  func testResultNotLinearizable() {
    let witness = NonLinearizableWitness(
      conflictingOperations: [],
      explanation: "test",
      minimalHistory: [],
      proofOfViolation: "proof"
    )

    let result = LinearizabilityResult.notLinearizable(counterexample: witness)
    #expect(!result.isLinearizable)
  }

  // MARK: - LinearizationWitness Tests

  @Test("LinearizationWitness explanation")
  func testWitnessExplanation() {
    let step = VerificationStep(
      operationId: UUID(),
      description: "op1",
      stateBeforeJSON: "before",
      stateAfterJSON: "after"
    )

    let witness = LinearizationWitness(
      sequentialOrder: [UUID()],
      finalState: "final",
      verificationSteps: [step]
    )

    let explanation = witness.explanation()
    #expect(explanation.contains("Linearizable"))
    #expect(explanation.contains("final"))
  }

  // MARK: - NonLinearizableWitness Tests

  @Test("NonLinearizableWitness debug info")
  func testNonLinearizableDebugInfo() {
    let witness = NonLinearizableWitness(
      conflictingOperations: [UUID()],
      explanation: "Operations conflict",
      minimalHistory: [],
      proofOfViolation: "State mismatch"
    )

    let debug = witness.debugInfo()
    #expect(debug.contains("Non-linearizable"))
    #expect(debug.contains("Operations conflict"))
  }

  // MARK: - CounterOp Tests

  @Test("CounterOp cases")
  func testCounterOpCases() {
    let inc = CounterOp.increment(5)
    let dec = CounterOp.decrement(3)
    let get = CounterOp.get

    #expect(inc.description.contains("increment"))
    #expect(dec.description.contains("decrement"))
    #expect(get.description.contains("get"))
  }

  // MARK: - SetOp Tests

  @Test("SetOp cases exist")
  func testSetOpCases() {
    let add: SetOp<Int> = .add(1)
    let remove: SetOp<Int> = .remove(1)
    let contains: SetOp<Int> = .contains(1)

    #expect(add == .add(1))
    #expect(remove == .remove(1))
    #expect(contains == .contains(1))
  }

  // MARK: - SetResult Tests

  @Test("SetResult cases exist")
  func testSetResultCases() {
    let added: SetResult<Int> = .addResult(true)
    let removed: SetResult<Int> = .removeResult(false)
    let found: SetResult<Int> = .containsResult(true)

    #expect(added == .addResult(true))
    #expect(removed == .removeResult(false))
    #expect(found == .containsResult(true))
  }

  // MARK: - Counter Spec Tests

  @Test("Counter spec increment")
  func testCounterSpecIncrement() async {
    let spec: Spec<Int, CounterOp, Int> = Spec.counter()

    var state = 10
    let result = spec.apply(&state, .increment(5))

    #expect(result == 10)  // Returns old value
    #expect(state == 15)  // State updated
  }

  @Test("Counter spec decrement")
  func testCounterSpecDecrement() async {
    let spec: Spec<Int, CounterOp, Int> = Spec.counter()

    var state = 10
    let result = spec.apply(&state, .decrement(3))

    #expect(result == 10)  // Returns old value
    #expect(state == 7)  // State updated
  }

  @Test("Counter spec get")
  func testCounterSpecGet() async {
    let spec: Spec<Int, CounterOp, Int> = Spec.counter()

    var state = 42
    let result = spec.apply(&state, .get)

    #expect(result == 42)
    #expect(state == 42)  // State unchanged
  }

  // MARK: - Set Spec Tests

  @Test("Set spec add")
  func testSetSpecAdd() async {
    let spec: Spec<Set<Int>, SetOp<Int>, SetResult<Int>> = Spec.set()

    var state: Set<Int> = [1, 2, 3]
    let result = spec.apply(&state, .add(4))

    #expect(result == .addResult(true))
    #expect(state.contains(4))
  }

  @Test("Set spec add duplicate")
  func testSetSpecAddDuplicate() async {
    let spec: Spec<Set<Int>, SetOp<Int>, SetResult<Int>> = Spec.set()

    var state: Set<Int> = [1, 2, 3]
    let result = spec.apply(&state, .add(2))

    #expect(result == .addResult(false))  // Was already present
  }

  @Test("Set spec contains")
  func testSetSpecContains() async {
    let spec: Spec<Set<Int>, SetOp<Int>, SetResult<Int>> = Spec.set()

    var state: Set<Int> = [1, 2, 3]
    let result1 = spec.apply(&state, .contains(2))
    let result2 = spec.apply(&state, .contains(99))

    #expect(result1 == .containsResult(true))
    #expect(result2 == .containsResult(false))
  }

  // MARK: - Helper Functions

  func makeOperation(
    start: ContinuousClock.Instant,
    end: ContinuousClock.Instant,
    call: Int
  ) -> InvariantCore.Operation<Int, Int> {
    InvariantCore.Operation(
      call: call,
      response: call * 2,
      startTime: start,
      endTime: end,
      threadId: ThreadID(1),
      context: OperationContext(threadId: ThreadID(1), operationName: "test")
    )
  }
}
