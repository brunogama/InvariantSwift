/// ISP Functional Tests - Integration tests for ISP-0003 through ISP-0006
///
/// This file contains functional tests that exercise the actual runtime behavior
/// of the types and utilities implemented in these ISPs.

import Testing

@testable import InvariantSwift

// MARK: - ISP-0003: Rule-Based Stateful Testing

@Suite("ISP-0003: Rule-Based Stateful Testing")
struct RuleBasedStatefulTests {

  @Test("AnyRule wraps rules correctly")
  func anyRuleWrapsRules() {
    let rule = AnyRule<MockStateMachine>(
      name: "increment",
      precondition: { $0.value < 100 },
      execute: { $0.value += 1 }
    )
    #expect(rule.name == "increment")

    var state = MockStateMachine()
    #expect(rule.precondition(state) == true)
    try! rule.execute(&state)
    #expect(state.value == 1)
  }

  @Test("ExecutedStep records execution history")
  func executedStepRecordsHistory() {
    let step = ExecutedStep(
      ruleName: "push",
      arguments: "42"
    )
    #expect(step.ruleName == "push")
    #expect(step.arguments == "42")
  }

  @Test("RuleBasedTestResult passed case")
  func resultPassedCase() {
    let result = RuleBasedTestResult.passed(examples: 100, totalSteps: 500)
    if case .passed(let examples, let steps) = result {
      #expect(examples == 100)
      #expect(steps == 500)
    } else {
      Issue.record("Expected .passed case")
    }
  }

  @Test("RuleBasedTestResult invariantFailed case")
  func resultInvariantFailedCase() {
    let result = RuleBasedTestResult.invariantFailed(
      invariant: "count >= 0",
      steps: [ExecutedStep(ruleName: "decrement")],
      shrunkSteps: nil
    )
    if case .invariantFailed(let inv, let steps, _) = result {
      #expect(inv == "count >= 0")
      #expect(steps.count == 1)
    } else {
      Issue.record("Expected .invariantFailed case")
    }
  }
}

// Mock for testing
struct MockStateMachine: RuleBasedStateMachine, Sendable {
  var value: Int = 0

  init() {}

  static var rules: [AnyRule<MockStateMachine>] {
    [
      AnyRule(name: "increment", precondition: { $0.value < 100 }, execute: { $0.value += 1 }),
      AnyRule(name: "decrement", precondition: { $0.value > 0 }, execute: { $0.value -= 1 }),
    ]
  }

  static var invariants: [(String, (MockStateMachine) -> Bool)] {
    [
      ("value >= 0", { $0.value >= 0 }),
      ("value <= 100", { $0.value <= 100 }),
    ]
  }

  static func run(maxSteps: Int, maxExamples: Int) async throws {
    // Test implementation
  }
}

// MARK: - ISP-0004: Example Database and Reproducible Failures

@Suite("ISP-0004: Example Database and Reproducible Failures")
struct ExampleDatabaseTests {

  @Test("TestIdentifier creates unique storage keys")
  func testIdentifierStorageKey() {
    let id = TestIdentifier(
      module: "TestModule",
      file: "TestFile.swift",
      function: "testFunction(x:y:)",
      signature: "Int,String"
    )
    #expect(id.storageKey.contains("TestModule"))
    #expect(id.storageKey.contains("testFunction"))
  }

  @Test("TestIdentifier creates directory-safe names")
  func testIdentifierDirectoryName() {
    let id = TestIdentifier(
      module: "Module",
      file: "File.swift",
      function: "test(x:y:)",
      signature: "Int"
    )
    let dirName = id.directoryName
    #expect(!dirName.contains("("))
    #expect(!dirName.contains(")"))
    #expect(!dirName.contains(":"))
  }

  @Test("FailingExample captures all metadata")
  func failingExampleMetadata() {
    let example = FailingExample(
      seed: 0xDEAD_BEEF,
      size: 42,
      shrinkPath: [0, 1, 3],
      failureMessage: "Property failed"
    )
    #expect(example.seed == 0xDEAD_BEEF)
    #expect(example.size == 42)
    #expect(example.shrinkPath == [0, 1, 3])
    #expect(example.shrinkPathString == "0:1:3")
  }

  @Test("FailingExample generates @Reproduce annotation")
  func failingExampleReproduceAnnotation() {
    let example = FailingExample(
      seed: 0xABCD,
      size: 10,
      shrinkPath: [1, 2],
      failureMessage: "Failed"
    )
    let annotation = example.reproduceAnnotation()
    #expect(annotation.contains("@Reproduce"))
    #expect(annotation.contains("seed: 0xABCD"))
    #expect(annotation.contains("size: 10"))
    #expect(annotation.contains("path: \"1:2\""))
  }

  @Test("FailingExampleDatabase saves and retrieves examples")
  func databaseSavesAndRetrieves() async {
    let db = FailingExampleDatabase(backend: .memory)
    let testID = TestIdentifier(
      module: "Test",
      file: "Test.swift",
      function: "testFn()",
      signature: ""
    )
    let example = FailingExample(
      seed: 12345,
      size: 50,
      failureMessage: "Test failure"
    )

    await db.save(testID: testID, example: example)
    let retrieved = await db.examples(for: testID)

    #expect(retrieved.count == 1)
    #expect(retrieved.first?.seed == 12345)
  }

  @Test("FailingExampleDatabase marks examples as fixed")
  func databaseMarksFixed() async {
    let db = FailingExampleDatabase(backend: .memory)
    let testID = TestIdentifier(
      module: "Test",
      file: "Test.swift",
      function: "testFn()",
      signature: ""
    )
    let example = FailingExample(
      seed: 12345,
      size: 50,
      failureMessage: "Test failure"
    )

    await db.save(testID: testID, example: example)
    await db.markFixed(testID: testID, example: example)
    let retrieved = await db.examples(for: testID)

    #expect(retrieved.count == 0)
  }

  @Test("ReproduceReport generates formatted output")
  func reproduceReportFormatsOutput() {
    let testID = TestIdentifier(
      module: "Test",
      file: "Test.swift",
      function: "testFn()",
      signature: ""
    )
    let example = FailingExample(
      seed: 0xDEAD,
      size: 10,
      failureMessage: "Failed"
    )
    let report = ReproduceReport(
      testIdentifier: testID,
      example: example,
      shrunkInput: "[1, 2]",
      shrinkSteps: 5
    )
    let desc = report.description
    #expect(desc.contains("Property failed"))
    #expect(desc.contains("@Reproduce"))
  }
}

// MARK: - ISP-0005: Differential Testing

@Suite("ISP-0005: Differential Testing")
struct DifferentialTestingTests {

  @Test("ErrorBehavior enum values exist")
  func errorBehaviorValues() {
    let behaviors: [ErrorBehavior] = [
      .mustMatch,
      .bothThrowOrBothSucceed,
      .candidateMaySucceedMore,
      .ignoreErrors,
    ]
    #expect(behaviors.count == 4)
  }

  @Test("DifferentialResult detects divergence on different outputs")
  func resultDetectsDivergence() {
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .success(100),
      candidateOutput: .success(200)
    )
    #expect(result.diverges == true)
  }

  @Test("DifferentialResult detects no divergence on same outputs")
  func resultDetectsNoDivergence() {
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .success(100),
      candidateOutput: .success(100)
    )
    #expect(result.diverges == false)
  }

  @Test("DifferentialResult handles both throwing")
  func resultHandlesBothThrowing() {
    struct TestError: Error {}
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .failure(TestError()),
      candidateOutput: .failure(TestError())
    )
    #expect(result.diverges(errorBehavior: .bothThrowOrBothSucceed) == false)
  }

  @Test("DifferentialResult with custom comparer")
  func resultWithCustomComparer() {
    let result = DifferentialResult<Int, Double>(
      input: 42,
      referenceOutput: .success(3.14159),
      candidateOutput: .success(3.14160),
      comparer: { abs($0 - $1) < 0.001 }
    )
    #expect(result.diverges == false)
  }

  @Test("DifferentialTester runs both implementations")
  func testerRunsBoth() throws {
    let tester = DifferentialTester<Int, Int>(
      reference: { $0 * 2 },
      candidate: { $0 + $0 }
    )
    let result = tester.test(21)
    #expect(result.diverges == false)
  }

  @Test("DifferentialTester detects differences")
  func testerDetectsDifferences() throws {
    let tester = DifferentialTester<Int, Int>(
      reference: { $0 * 2 },
      candidate: { $0 * 3 }
    )
    let result = tester.test(10)
    #expect(result.diverges == true)
  }

  @Test("DifferentialTestError provides detailed description")
  func testErrorDescription() {
    let result = DifferentialResult<Int, Int>(
      input: 42,
      referenceOutput: .success(84),
      candidateOutput: .success(126)
    )
    let error = DifferentialTestError(
      result: result,
      referenceName: "double",
      candidateName: "triple"
    )
    let desc = error.description
    #expect(desc.contains("Differential test failed"))
    #expect(desc.contains("Input: 42"))
    #expect(desc.contains("double: 84"))
    #expect(desc.contains("triple: 126"))
  }
}

// MARK: - ISP-0006: Contract Testing

@Suite("ISP-0006: Contract Testing")
struct ContractTestingTests {

  @Test("ContractConfig default values")
  func configDefaults() {
    // Default values (may be changed globally, so just test they exist)
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
    let op = ContractOperation<Int>(
      name: "increment",
      precondition: { $0 < 100 },
      execute: { $0 += 1 },
      postconditions: [{ old, new in new == old + 1 }]
    )
    #expect(op.name == "increment")
    #expect(op.precondition(50) == true)
    #expect(op.precondition(100) == false)
  }

  @Test("ContractTestRunner runs operations")
  func runnerRunsOperations() {
    let operations = [
      ContractOperation<MockCounter>(
        name: "increment",
        precondition: { $0.value < 10 },
        execute: { $0.value += 1 },
        postconditions: [{ old, new in new.value == old.value + 1 }]
      ),
      ContractOperation<MockCounter>(
        name: "decrement",
        precondition: { $0.value > 0 },
        execute: { $0.value -= 1 },
        postconditions: [{ old, new in new.value == old.value - 1 }]
      ),
    ]

    let invariants: [@Sendable (MockCounter) -> Bool] = [
      { $0.value >= 0 },
      { $0.value <= 10 },
    ]

    let runner = ContractTestRunner(
      operations: operations,
      invariants: invariants
    )

    var rng = SystemRandomNumberGenerator()
    let result = runner.run(
      initialState: MockCounter(value: 5),
      operationCount: 50,
      using: &rng
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

// Helper for contract testing
struct MockCounter: ContractProtocol, Sendable {
  var value: Int

  func verifyInvariants() -> Bool {
    value >= 0 && value <= 10
  }
}
