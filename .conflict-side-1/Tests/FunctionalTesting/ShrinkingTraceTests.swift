// ShrinkingTraceTests.swift
// InvariantSwift Tests
//
// Tests for the ShrinkingTrace visualization system.

import Testing
import Foundation
@testable import InvariantCore
@testable import InvariantSwift

@Suite("ShrinkingTrace Tests")
struct ShrinkingTraceTests {

  // MARK: - Basic Trace Tests

  @Test("Create trace and record steps")
  func testBasicTrace() {
    let trace = ShrinkingTrace<[Int]>(original: [1, 2, 3, 4, 5])

    trace.record(value: [1, 2, 3, 4], passed: false, depth: 1)
    trace.record(value: [1, 2, 3], passed: false, depth: 2)
    trace.record(value: [1, 3], passed: false, depth: 3)
    trace.record(value: [1], passed: false, depth: 4)
    trace.record(value: [], passed: true, depth: 5)
    trace.complete(minimal: [1])

    #expect(trace.totalAttempts == 5)
    #expect(trace.successfulShrinks == 4)  // 4 steps that failed = successful shrinks
    #expect(trace.maxDepth == 5)
    #expect(trace.minimal == [1])
  }

  @Test("Formatted output contains expected elements")
  func testFormattedOutput() {
    let trace = ShrinkingTrace<Int>(original: 100)
    trace.record(value: 50, passed: false, depth: 1)
    trace.record(value: 25, passed: false, depth: 2)
    trace.record(value: 12, passed: true, depth: 3)
    trace.complete(minimal: 25)

    let output = trace.formattedOutput()

    #expect(output.contains("Original: 100"))
    #expect(output.contains("Step 1"))
    #expect(output.contains("50"))
    #expect(output.contains("Minimal counterexample: 25"))
    #expect(output.contains("Total attempts: 3"))
    #expect(output.contains("Successful shrinks: 2"))
  }

  @Test("Condensed summary is correct")
  func testCondensedSummary() {
    let trace = ShrinkingTrace<String>(original: "hello")
    trace.record(value: "hell", passed: false, depth: 1)
    trace.record(value: "hel", passed: false, depth: 2)
    trace.complete(minimal: "hel")

    let summary = trace.condensedSummary()

    #expect(summary.contains("hello"))
    #expect(summary.contains("hel"))
    #expect(summary.contains("2 shrinks"))
  }

  @Test("JSON output is valid")
  func testJSONOutput() {
    let trace = ShrinkingTrace<Int>(original: 42)
    trace.record(value: 21, passed: false, depth: 1)
    trace.complete(minimal: 21)

    let json = trace.toJSON()

    #expect(json.contains("\"original\""))
    #expect(json.contains("42"))
    #expect(json.contains("\"minimal\""))
    #expect(json.contains("21"))
    #expect(json.contains("\"steps\""))
  }

  // MARK: - Builder Tests

  @Test("Trace builder fluent API")
  func testTraceBuilder() {
    let trace = ShrinkingTraceBuilder(original: [1, 2, 3])
      .step([1, 2], passed: false, strategy: "removeElement")
      .step([1], passed: false, strategy: "removeElement")
      .step([], passed: true, strategy: "removeElement")
      .complete(minimal: [1])

    #expect(trace.totalAttempts == 3)
    #expect(trace.successfulShrinks == 2)
    #expect(trace.minimal == [1])

    // Check strategies are recorded
    let hasStrategy = trace.steps.allSatisfy { $0.strategy == "removeElement" }
    #expect(hasStrategy)
  }

  // MARK: - Simple Trace Factory Tests

  @Test("Simple trace factory method")
  func testSimpleTrace() {
    let trace = ShrinkingTrace.simple(
      from: 100,
      to: 1,
      through: [50, 25, 10, 5]
    )

    #expect(trace.original == 100)
    #expect(trace.minimal == 1)
    #expect(trace.totalAttempts == 4)
  }

  // MARK: - Custom Formatter Tests

  @Test("Custom value formatter")
  func testCustomFormatter() {
    struct Point: Sendable {
      let x: Int
      let y: Int
    }

    let trace = ShrinkingTrace(original: Point(x: 10, y: 20))
    trace.record(value: Point(x: 5, y: 10), passed: false, depth: 1)
    trace.complete(minimal: Point(x: 5, y: 10))

    let output = trace.formattedOutput { p in
      "(\(p.x), \(p.y))"
    }

    #expect(output.contains("(10, 20)"))
    #expect(output.contains("(5, 10)"))
  }

  // MARK: - Edge Cases

  @Test("Empty trace")
  func testEmptyTrace() {
    let trace = ShrinkingTrace<Int>(original: 42)
    trace.complete(minimal: 42)

    #expect(trace.totalAttempts == 0)
    #expect(trace.successfulShrinks == 0)
    #expect(trace.maxDepth == 0)
    #expect(trace.minimal == 42)
  }

  @Test("All passing steps")
  func testAllPassingSteps() {
    let trace = ShrinkingTrace<Int>(original: 10)
    trace.record(value: 5, passed: true, depth: 1)
    trace.record(value: 8, passed: true, depth: 1)
    trace.record(value: 9, passed: true, depth: 1)
    trace.complete(minimal: 10)

    #expect(trace.successfulShrinks == 0)
    #expect(trace.minimal == 10)
  }
}
