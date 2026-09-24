import Testing
@testable import InvariantSwiftAdvanced

@Suite("Invariant verification")
struct InvariantVerificationTests {
  @Test("A predicate must hold in every state where its operands are present")
  func predicateMustHoldInEveryApplicableState() async throws {
    let invariant = makeInvariant(predicate: "balance >= 0")
    let trace = ExecutionTrace(
      input: ExecutionState(variables: ["balance": .integer(10)]),
      output: ExecutionState(variables: ["balance": .integer(-1)]),
      intermediateStates: [ExecutionState(variables: ["balance": .integer(3)])]
    )

    let result = try #require(
      await InvariantMiningEngine().verifyInvariants([invariant], against: [trace]).first
    )

    #expect(result.successes == 0)
    #expect(result.violations.map(\.trace) == [trace.id])
    #expect(result.successRate == 0)
  }

  @Test("Trace-scoped collection operands compare input and output")
  func traceScopedCollectionOperands() async throws {
    let invariant = makeInvariant(predicate: "input.items.count == output.items.count")
    let matching = ExecutionTrace(
      input: ExecutionState(variables: ["items": .array([.integer(1), .integer(2)])]),
      output: ExecutionState(variables: ["items": .array([.integer(2), .integer(1)])])
    )
    let shorterOutput = ExecutionTrace(
      input: ExecutionState(variables: ["items": .array([.integer(1), .integer(2)])]),
      output: ExecutionState(variables: ["items": .array([.integer(1)])])
    )

    let result = try #require(
      await InvariantMiningEngine().verifyInvariants(
        [invariant],
        against: [matching, shorterOutput]
      ).first
    )

    #expect(result.successes == 1)
    #expect(result.violations.map(\.trace) == [shorterOutput.id])
    #expect(result.successRate == 0.5)
  }

  @Test("Trace-scoped size resolves return values")
  func traceScopedSizeResolvesReturnValues() async throws {
    let invariant = makeInvariant(predicate: "input.size == output.size")
    let trace = ExecutionTrace(
      input: ExecutionState(variables: [:], returnValue: .array([.integer(1)])),
      output: ExecutionState(variables: [:], returnValue: .array([.integer(2)]))
    )

    let result = try #require(
      await InvariantMiningEngine().verifyInvariants([invariant], against: [trace]).first
    )

    #expect(result.successes == 1)
    #expect(result.violations.isEmpty)
  }

  @Test("Null and unsupported predicates fail closed")
  func nullAndUnsupportedPredicatesFailClosed() async {
    let trace = ExecutionTrace(
      input: ExecutionState(variables: [:]),
      output: ExecutionState(variables: [:])
    )
    let invariants = [
      makeInvariant(predicate: "result != null"),
      makeInvariant(predicate: "clustered_pattern"),
    ]

    let results = await InvariantMiningEngine().verifyInvariants(invariants, against: [trace])

    #expect(results.map(\.successes) == [0, 0])
    #expect(results.allSatisfy { $0.violations.count == 1 })
  }

  @Test("Equal infinities satisfy numeric equality")
  func equalInfinitiesSatisfyEquality() async throws {
    let invariant = makeInvariant(predicate: "lhs == rhs")
    let state = ExecutionState(
      variables: ["lhs": .double(.infinity), "rhs": .double(.infinity)]
    )
    let trace = ExecutionTrace(input: state, output: state)

    let result = try #require(
      await InvariantMiningEngine().verifyInvariants([invariant], against: [trace]).first
    )

    #expect(result.successes == 1)
    #expect(result.violations.isEmpty)
  }

  private func makeInvariant(predicate: String) -> DiscoveredInvariant {
    DiscoveredInvariant(
      predicate: predicate,
      confidence: 1,
      supportCount: 1,
      category: .numerical,
      discoveryMethod: .statistical
    )
  }
}
