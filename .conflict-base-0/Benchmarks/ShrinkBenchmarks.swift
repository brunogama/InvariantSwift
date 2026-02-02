// Benchmarks/ShrinkBenchmarks.swift
// Shrinking performance benchmarks for InvariantSwift

import Benchmark
import InvariantCore

// MARK: - Configuration

private let benchmarkSeed = Seed(value: 42)
private let benchmarkSize = Size(value: 10)

// MARK: - Registration

func registerShrinkBenchmarks() {
  // MARK: - Fast-Failing Predicates

  benchmark("Shrink: divisibility (fast-fail)") {
    let property = Property<Int>(generator: Gen.int(in: 1...1000)) { n in
      n % 7 != 0  // Fails on multiples of 7
    }
    let config = PropertyConfig(iterations: 50, maxShrinks: 100)
    _ = runPropertySynchronously(property, config: config)
  }

  benchmark("Shrink: contains element") {
    // Fully qualified type to avoid Gen<[Any]> fallback
    let gen = Gen<[Int]>.array(Gen.int(in: 0...100))
    let property = Property<[Int]>(generator: gen) { array in
      !array.contains(42)  // Fails when 42 is present
    }
    let config = PropertyConfig(iterations: 50, maxShrinks: 100)
    _ = runPropertySynchronously(property, config: config)
  }

  // MARK: - Structural Shrinking

  benchmark("Shrink: nested array") {
    // Fully qualified types at each level for proper Sendable conformance
    let innerGen = Gen<[Int]>.array(Gen.int(in: 0...50))
    let gen = Gen<[[Int]]>.array(innerGen)
    let property = Property<[[Int]]>(generator: gen) { arrays in
      // Fails when any inner array sums to > 100
      arrays.allSatisfy { $0.reduce(0, +) <= 100 }
    }
    let config = PropertyConfig(iterations: 30, maxShrinks: 200)
    _ = runPropertySynchronously(property, config: config)
  }

  benchmark("Shrink: dictionary structure") {
    let gen = Gen<[String: Int]>.dictionary(
      Gen.string,
      Gen.int(in: 0...100)
    )
    let property = Property<[String: Int]>(generator: gen) { dict in
      dict.values.reduce(0, +) <= 200  // Fails when sum exceeds 200
    }
    let config = PropertyConfig(iterations: 30, maxShrinks: 150)
    _ = runPropertySynchronously(property, config: config)
  }

  // MARK: - Stress Tests

  benchmark("Shrink: large array sum (stress)") {
    // Fully qualified type to avoid Gen<[Any]> fallback
    let gen = Gen<[Int]>.array(Gen.int(in: 1...20))
    let property = Property<[Int]>(generator: gen) { array in
      array.reduce(0, +) <= 50  // Fails on many inputs
    }
    let config = PropertyConfig(iterations: 20, maxShrinks: 500)
    _ = runPropertySynchronously(property, config: config)
  }

  benchmark("Shrink: deep nesting (3 levels)") {
    // Fully qualified types at each level for proper Sendable conformance
    let level1 = Gen<[Int]>.array(Gen.int(in: 0...10))
    let level2 = Gen<[[Int]]>.array(level1)
    let gen = Gen<[[[Int]]]>.array(level2)
    let property = Property<[[[Int]]]>(generator: gen) { nested in
      // Fails when total element count exceeds threshold
      let total = nested.flatMap { $0.flatMap { $0 } }.count
      return total <= 20
    }
    let config = PropertyConfig(iterations: 15, maxShrinks: 300)
    _ = runPropertySynchronously(property, config: config)
  }
}
