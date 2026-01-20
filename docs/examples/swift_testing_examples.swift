// swift_testing_examples.swift
// InvariantSwift Examples
//
// Runnable examples demonstrating Swift Testing integration.
// Place in your test target to run.

import Testing
import InvariantSwift

// MARK: - Basic Property Tests

/// Example 1: Sorting is idempotent
@Test func testSortingIdempotent() async throws {
  let property = Property(generator: Gen.array(of: Gen.int)) { array in
    array.sorted() == array.sorted().sorted()
  }

  try await checkProperty(property)
}

/// Example 2: Reversing twice returns original
@Test func testReverseInvolution() async throws {
  let property = Property(generator: Gen.array(of: Gen.int)) { array in
    Array(array.reversed().reversed()) == array
  }

  try await checkProperty(property)
}

/// Example 3: String concatenation length
@Test func testStringConcatLength() async throws {
  let twoStrings = Gen<(String, String)>.tuple(Gen.string, Gen.string)

  let property = Property(generator: twoStrings) { a, b in
    (a + b).count == a.count + b.count
  }

  try await checkProperty(property)
}

// MARK: - Using @PropertyTest Macro

/// Example 4: Array first equals last of reversed
@PropertyTest("First element equals last of reversed")
func testFirstLastReversed(xs: [Int]) {
  if !xs.isEmpty {
    #expect(xs.first == xs.reversed().last)
  }
}

/// Example 5: Optional unwrap safety
@PropertyTest("Optional mapping preserves nil", iterations: 200)
func testOptionalMap(x: Int?) {
  if x == nil {
    #expect(x.map { $0 * 2 } == nil)
  } else {
    #expect(x.map { $0 * 2 } != nil)
  }
}

// MARK: - With Configuration

/// Example 6: Reproducible test with seed
@Test func testWithSeed() async throws {
  let config = PropertyConfig(
    iterations: 100,
    seed: Seed(value: 42)  // Always reproduces same sequence
  )

  let property = Property(generator: Gen.int) { n in
    n + 0 == n  // Additive identity
  }

  try await checkProperty(property, config: config)
}

/// Example 7: Thorough testing with many iterations
@Test func testThorough() async throws {
  let config = PropertyConfig(
    iterations: 1000,
    maxShrinks: 500
  )

  let property = Property(generator: Gen.int) { n in
    n * 1 == n  // Multiplicative identity
  }

  try await checkProperty(property, config: config)
}

// MARK: - With Assumptions

/// Example 8: Non-empty array has a head
@Test func testNonEmptyHead() async throws {
  let property = Property(
    generator: Gen.array(of: Gen.int),
    assumption: { !$0.isEmpty }
  ) { array in
    array.first != nil
  }

  try await checkProperty(property)
}

// MARK: - Collecting Statistics

/// Example 9: With statistics collection
@Test func testWithStatistics() async throws {
  let collector = StatisticsCollector(testName: "testWithStatistics")

  let property = Property(generator: Gen.int(in: 0...100)) { n in
    collector.recordGeneration()
    return n >= 0 && n <= 100
  }

  try await checkProperty(property)

  let stats = collector.finalize()
  print(stats.compact())
}

// MARK: - Custom Generators

/// Example 10: Using custom generator
@Test func testCustomGenerator() async throws {
  struct Point {
    let x: Int
    let y: Int
  }

  let pointGen = Gen<Point> { rng, size in
    Point(
      x: Int.random(in: -size.value...size.value, using: &rng),
      y: Int.random(in: -size.value...size.value, using: &rng)
    )
  }

  let property = Property(generator: pointGen) { point in
    // Distance from origin is non-negative (simplified)
    point.x * point.x + point.y * point.y >= 0
  }

  try await checkProperty(property)
}
