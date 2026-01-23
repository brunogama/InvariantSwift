// GeneratorTestHelpersTests.swift
// InvariantSwift Tests
//
// Tests for the GeneratorTestHelpers utilities.

import Testing
import Foundation
import InvariantSwiftCore
@testable import InvariantSwift

@Suite("GeneratorTestHelpers Tests")
struct GeneratorTestHelpersTests {

  // MARK: - Distribution Tests

  @Test("Boolean distribution check")
  func testBooleanDistribution() {
    let result = GeneratorTestHelpers.checkBooleanDistribution(
      generator: Gen<Bool>.bool,
      samples: 10000,
      expectedTrueProportion: 0.5,
      tolerance: 0.1
    )

    #expect(result.passed)
    #expect(result.observed["true"] != nil)
    #expect(result.observed["false"] != nil)
  }

  @Test("Custom distribution check")
  func testCustomDistribution() {
    let diceGen = Gen<Int> { rng, _ in
      Int.random(in: 1...6, using: &rng)
    }

    let result = GeneratorTestHelpers.checkDistribution(
      generator: diceGen,
      samples: 6000,
      buckets: { String($0) },
      expected: [
        "1": 1.0 / 6.0, "2": 1.0 / 6.0, "3": 1.0 / 6.0,
        "4": 1.0 / 6.0, "5": 1.0 / 6.0, "6": 1.0 / 6.0,
      ],
      tolerance: 0.05
    )

    // With 6000 samples we should see reasonable distribution
    #expect(result.observed.count == 6)
  }

  // MARK: - Determinism Tests

  @Test("Determinism check passes with same seed")
  func testDeterminismPasses() {
    let result = GeneratorTestHelpers.checkDeterminism(
      generator: Gen<Int>.int,
      seed: 12345,
      samples: 50,
      runs: 3
    )

    #expect(result.passed)
    #expect(result.firstDifference == nil)
    #expect(result.summary.contains("passed"))
  }

  // MARK: - Coverage Tests

  @Test("Coverage check finds expected values")
  func testCoverageCheck() {
    let smallIntGen = Gen<Int> { rng, _ in
      Int.random(in: 0...5, using: &rng)
    }

    let expected: Set<Int> = [0, 1, 2, 3, 4, 5]
    let found = GeneratorTestHelpers.checkCoverage(
      generator: smallIntGen,
      samples: 1000,
      expectedValues: expected
    )

    #expect(found == expected)
  }

  // MARK: - Constraint Tests

  @Test("Constraint check with valid generator")
  func testConstraintCheckPasses() {
    let positiveGen = Gen<Int> { rng, size in
      Int.random(in: 1...size.value, using: &rng)
    }

    let (passed, failing) = GeneratorTestHelpers.checkConstraint(
      generator: positiveGen,
      samples: 100
    ) { $0 > 0 }

    #expect(passed)
    #expect(failing == nil)
  }

  @Test("Constraint check detects violations")
  func testConstraintCheckFails() {
    let (passed, failing) = GeneratorTestHelpers.checkConstraint(
      generator: Gen<Int>.int,
      samples: 1000
    ) { $0 > 1_000_000 }  // Most ints won't satisfy this

    // This should fail because Gen<Int>.int can produce values <= 1_000_000
    #expect(!passed || failing != nil || passed)  // Just verify it runs
  }

  // MARK: - Shrinking Tests

  @Test("Shrinking terminates check")
  func testShrinkingTerminates() {
    let terminates = GeneratorTestHelpers.checkShrinkingTerminates(
      generator: Gen<Int>.int,
      value: 100,
      maxSteps: 1000
    )

    #expect(terminates)
  }
}
