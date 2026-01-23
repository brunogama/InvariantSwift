import Testing
import Foundation
@testable import InvariantSwift
import InvariantSwiftCore

@Suite("RunReport JSON Schema Tests")
struct RunReportJSONSchemaTests {

  @Test("RunReport can be encoded to JSON")
  func testJSONEncoding() throws {
    let report = RunReport(
      version: 1,
      propertyName: "Test Property",
      outcome: .success,
      statistics: .init(
        totalIterations: 100,
        successfulIterations: 100,
        failedIterations: 0,
        discardedCases: 0,
        durationMs: 1234
      ),
      failure: nil,
      classification: nil
    )

    let jsonData = try report.toJSON(prettyPrinted: true)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    #expect(jsonString.contains("\"version\" : 1"))
    #expect(jsonString.contains("\"outcome\" : \"success\""))
    #expect(jsonString.contains("\"totalIterations\" : 100"))
  }

  @Test("RunReport with failure details can be encoded")
  func testFailureEncoding() throws {
    let token = ReplayToken(seed: 42, iterations: 100)
    let failure = RunReport.FailureDetails(
      failedAtIteration: 50,
      reason: "Predicate failed",
      originalCounterexample: "[1, 2, 3]",
      minimalCounterexample: "[1]",
      replayToken: token
    )

    let report = RunReport(
      version: 1,
      propertyName: "Failing Property",
      outcome: .failed,
      statistics: .init(
        totalIterations: 50,
        successfulIterations: 49,
        failedIterations: 1,
        discardedCases: 0,
        durationMs: 500,
        shrinkSteps: 3
      ),
      failure: failure,
      classification: nil
    )

    let jsonData = try report.toJSON(prettyPrinted: true)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    #expect(jsonString.contains("\"outcome\" : \"failed\""))
    #expect(jsonString.contains("\"failedAtIteration\" : 50"))
    #expect(jsonString.contains("\"minimalCounterexample\" : \"[1]\""))
    #expect(jsonString.contains("\"shrinkSteps\" : 3"))
  }

  @Test("RunReport can be decoded from JSON")
  func testJSONDecoding() throws {
    let jsonString = """
      {
        "version": 1,
        "propertyName": "Test Property",
        "outcome": "success",
        "statistics": {
          "totalIterations": 100,
          "successfulIterations": 100,
          "failedIterations": 0,
          "discardedCases": 0,
          "durationMs": 1234
        }
      }
      """

    let report = try RunReport.fromJSONString(jsonString)

    #expect(report.version == 1)
    #expect(report.propertyName == "Test Property")
    #expect(report.outcome == .success)
    #expect(report.statistics.totalIterations == 100)
    #expect(report.statistics.durationMs == 1234)
  }

  @Test("RunReport roundtrip preserves data")
  func testRoundtrip() throws {
    let original = RunReport(
      version: 1,
      propertyName: "Roundtrip Test",
      outcome: .gaveUp,
      statistics: .init(
        totalIterations: 200,
        successfulIterations: 0,
        failedIterations: 0,
        discardedCases: 150,
        durationMs: 789
      ),
      failure: nil,
      classification: nil
    )

    let jsonData = try original.toJSON()
    let decoded = try RunReport.fromJSON(jsonData)

    #expect(decoded.version == original.version)
    #expect(decoded.propertyName == original.propertyName)
    #expect(decoded.outcome == original.outcome)
    #expect(decoded.statistics.totalIterations == original.statistics.totalIterations)
    #expect(decoded.statistics.discardedCases == original.statistics.discardedCases)
  }

  @Test("RunReport schema is stable across versions")
  func testSchemaStability() throws {
    let report = RunReport(
      version: 1,
      propertyName: nil,
      outcome: .success,
      statistics: .init(
        totalIterations: 1,
        successfulIterations: 1,
        failedIterations: 0,
        discardedCases: 0,
        durationMs: 10
      ),
      failure: nil,
      classification: nil
    )

    let jsonData = try report.toJSON(prettyPrinted: false)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    let expectedKeys = [
      "\"version\"",
      "\"outcome\"",
      "\"statistics\"",
      "\"totalIterations\"",
      "\"successfulIterations\"",
      "\"failedIterations\"",
      "\"discardedCases\"",
      "\"durationMs\"",
    ]

    for key in expectedKeys {
      #expect(jsonString.contains(key), "Schema must contain \(key)")
    }
  }

  @Test("RunReport factory method creates valid report from success result")
  func testFactoryMethodSuccess() throws {
    let result: PropertyResult<Int> = .success(iterations: 100)
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000)

    let report = RunReport.from(
      result,
      propertyName: "Factory Test",
      durationMs: 500,
      config: config
    )

    #expect(report.outcome == .success)
    #expect(report.statistics.totalIterations == 100)
    #expect(report.statistics.successfulIterations == 100)
    #expect(report.statistics.failedIterations == 0)
    #expect(report.failure == nil)
  }

  @Test("RunReport factory method creates valid report from failure result")
  func testFactoryMethodFailure() throws {
    let seed = Seed(value: 42)
    let result: PropertyResult<Int> = .failure(
      counterexample: 12345,
      iterations: 50,
      shrunk: 1,
      reason: .predicateFailed,
      seed: seed
    )
    let config = PropertyConfig(iterations: 100, maxShrinks: 1000, seed: seed)

    let report = RunReport.from(
      result,
      propertyName: "Failure Test",
      durationMs: 300,
      config: config
    )

    #expect(report.outcome == .failed)
    #expect(report.statistics.failedIterations == 1)
    #expect(report.failure != nil)
    #expect(report.failure?.failedAtIteration == 50)
    #expect(report.failure?.originalCounterexample.contains("12345") == true)
    #expect(report.failure?.minimalCounterexample.contains("1") == true)
  }

  @Test("Shrink trace is included in failure details")
  func testShrinkTrace() throws {
    let token = ReplayToken(seed: 42, iterations: 100)
    let shrinkTrace = [
      RunReport.ShrinkStep(candidate: "[1, 2, 3]", stillFails: true),
      RunReport.ShrinkStep(candidate: "[1, 2]", stillFails: true),
      RunReport.ShrinkStep(candidate: "[1]", stillFails: true),
    ]

    let failure = RunReport.FailureDetails(
      failedAtIteration: 50,
      reason: "Predicate failed",
      originalCounterexample: "[1, 2, 3, 4, 5]",
      minimalCounterexample: "[1]",
      replayToken: token,
      shrinkTrace: shrinkTrace
    )

    let report = RunReport(
      version: 1,
      propertyName: "Shrink Trace Test",
      outcome: .failed,
      statistics: .init(
        totalIterations: 50,
        successfulIterations: 49,
        failedIterations: 1,
        discardedCases: 0,
        durationMs: 200,
        shrinkSteps: 3
      ),
      failure: failure,
      classification: nil
    )

    let jsonData = try report.toJSON(prettyPrinted: true)
    let jsonString = String(data: jsonData, encoding: .utf8)!

    #expect(jsonString.contains("\"shrinkTrace\""))
    #expect(jsonString.contains("\"[1, 2, 3]\""))
    #expect(jsonString.contains("\"stillFails\""))
  }
}
