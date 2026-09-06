/// ISP Functional Tests - Integration tests for ISP-0003 through ISP-0006
///
/// This file contains functional tests that exercise the actual runtime behavior
/// of the types and utilities implemented in these ISPs.

import Testing

import InvariantSwiftCore
@testable import InvariantSwift

// MARK: - ISP-0003: Rule-Based Stateful Testing

@Suite("ISP-0003: Rule-Based Stateful Testing")
struct RuleBasedStatefulTests {

  @Test("AnyRule wraps rules correctly")
  func anyRuleWrapsRules() throws {
    let rule = AnyRule<MockStateMachine>(
      name: "increment",
      precondition: { $0.value < 100 },
      execute: { $0.value += 1 }
    )
    #expect(rule.name == "increment")

    var state = MockStateMachine()
    #expect(rule.precondition(state) == true)
    try rule.execute(&state)
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

  static var rules: [AnyRule<Self>] {
    [
      AnyRule(
        name: "increment",
        precondition: { $0.value < 100 },
        execute: { $0.value += 1 }
      ),
      AnyRule(
        name: "decrement",
        precondition: { $0.value > 0 },
        execute: { $0.value -= 1 }
      ),
    ]
  }

  static var invariants: [(String, (Self) -> Bool)] {
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
    let failure = FailingExampleFailure(
      seed: 0xDEAD_BEEF,
      size: 42,
      message: "Property failed"
    )
    let context = FailingExampleContext(shrinkPath: [0, 1, 3])
    let example = FailingExample(failure: failure, context: context)
    #expect(example.seed == 0xDEAD_BEEF)
    #expect(example.size == 42)
    #expect(example.shrinkPath == [0, 1, 3])
    #expect(example.shrinkPathString == "0:1:3")
  }

  @Test("FailingExample generates @Reproduce annotation")
  func failingExampleReproduceAnnotation() {
    let failure = FailingExampleFailure(
      seed: 0xABCD,
      size: 10,
      message: "Failed"
    )
    let context = FailingExampleContext(shrinkPath: [1, 2])
    let example = FailingExample(failure: failure, context: context)
    let annotation = example.reproduceAnnotation()
    #expect(annotation.contains("@Reproduce"))
    #expect(annotation.contains("seed: 0xABCD"))
    #expect(annotation.contains("size: 10"))
    #expect(annotation.contains("path: \"1:2\""))
  }

  @Test("FailingExampleDatabase saves and retrieves examples")
  func databaseSavesAndRetrieves() async {
    let database = FailingExampleDatabase(backend: .memory)
    let testID = TestIdentifier(
      module: "Test",
      file: "Test.swift",
      function: "testFn()",
      signature: ""
    )
    let failure = FailingExampleFailure(
      seed: 12345,
      size: 50,
      message: "Test failure"
    )
    let example = FailingExample(failure: failure)

    await database.save(testID: testID, example: example)
    let retrieved = await database.examples(for: testID)

    #expect(retrieved.count == 1)
    #expect(retrieved.first?.seed == 12345)
  }

  @Test("FailingExampleDatabase marks examples as fixed")
  func databaseMarksFixed() async {
    let database = FailingExampleDatabase(backend: .memory)
    let testID = TestIdentifier(
      module: "Test",
      file: "Test.swift",
      function: "testFn()",
      signature: ""
    )
    let failure = FailingExampleFailure(
      seed: 12345,
      size: 50,
      message: "Test failure"
    )
    let example = FailingExample(failure: failure)

    await database.save(testID: testID, example: example)
    await database.markFixed(testID: testID, example: example)
    let retrieved = await database.examples(for: testID)

    #expect(retrieved.isEmpty)
  }

  @Test("ReproduceReport generates formatted output")
  func reproduceReportFormatsOutput() {
    let testID = TestIdentifier(
      module: "Test",
      file: "Test.swift",
      function: "testFn()",
      signature: ""
    )
    let failure = FailingExampleFailure(
      seed: 0xDEAD,
      size: 10,
      message: "Failed"
    )
    let example = FailingExample(failure: failure)
    let report = ReproduceReport(
      testIdentifier: testID,
      example: example,
      shrunkInput: "[1, 2]",
      shrinkSteps: 5
    )
    #expect(report.description.contains("Property failed"))
    #expect(report.description.contains("@Reproduce"))
  }
}
