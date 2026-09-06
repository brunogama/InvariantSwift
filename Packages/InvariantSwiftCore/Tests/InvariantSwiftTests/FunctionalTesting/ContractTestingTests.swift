import Testing

@testable import InvariantSwift

@Suite("ISP-0006: Contract Testing")
struct ContractTestingTests {
  @Test("ContractConfig default values")
  func configDefaults() {
    _ = ContractConfig.runtimeChecks
    _ = ContractConfig.throwOnViolation
    _ = ContractConfig.verbose
  }

  @Test("ContractViolation captures all details")
  func violationCapturesDetails() {
    let violation = ContractViolation(
      type: .precondition,
      message: "!isEmpty",
      function: "pop()",
      file: "Stack.swift",
      line: 42
    )
    #expect(violation.type == .precondition)
    #expect(violation.message == "!isEmpty")
    #expect(violation.function == "pop()")
    #expect(violation.line == 42)
    #expect(violation.description.contains("precondition"))
  }

  @Test("ContractViolation types exist")
  func violationTypes() {
    let types: [ContractViolation.ViolationType] = [
      .precondition,
      .postcondition,
      .invariant,
    ]
    #expect(types.count == 3)
  }

  @Test("old() function captures value")
  func oldCapturesValue() {
    var counter = 0
    let captured = old(counter)
    counter += 1
    #expect(captured == 0)
    #expect(counter == 1)
  }

  @Test("ContractOperation holds operation details")
  func operationHoldsDetails() {
    let operation = ContractOperation<Int>(
      name: "increment",
      precondition: { $0 < 100 },
      execute: { $0 += 1 },
      postconditions: [{ old, new in new == old + 1 }]
    )
    #expect(operation.name == "increment")
    #expect(operation.precondition(50) == true)
    #expect(operation.precondition(100) == false)
  }

  @Test("ContractTestRunner runs operations")
  func runnerRunsOperations() {
    let runner = ContractTestRunner(
      operations: makeMockOperations(),
      invariants: makeMockInvariants()
    )
    var generator = SystemRandomNumberGenerator()
    let result = runner.run(
      initialState: MockCounter(value: 5),
      operationCount: 50,
      using: &generator
    )
    #expect(result.passed == true)
    #expect(result.operationsExecuted == 50)
  }

  @Test("ContractTestResult captures violations")
  func resultCapturesViolations() {
    let result = ContractTestResult(
      passed: false,
      operationsExecuted: 25,
      violationsFound: ["Invariant 0 failed"]
    )
    #expect(result.passed == false)
    #expect(result.violationsFound.count == 1)
  }
}

private struct MockCounter: ContractProtocol, Sendable {
  var value: Int

  func verifyInvariants() -> Bool {
    value >= 0 && value <= 10
  }
}

private func makeMockOperations() -> [ContractOperation<MockCounter>] {
  [
    ContractOperation(
      name: "increment",
      precondition: { $0.value < 10 },
      execute: { $0.value += 1 },
      postconditions: [{ old, new in new.value == old.value + 1 }]
    ),
    ContractOperation(
      name: "decrement",
      precondition: { $0.value > 0 },
      execute: { $0.value -= 1 },
      postconditions: [{ old, new in new.value == old.value - 1 }]
    ),
  ]
}

private func makeMockInvariants() -> [@Sendable (MockCounter) -> Bool] {
  [
    { $0.value >= 0 },
    { $0.value <= 10 },
  ]
}
