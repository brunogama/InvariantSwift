// ShrinkCombinatorTests.swift
// InvariantSwift Tests
//
// Comprehensive tests for Shrink combinators and Gen shrinking modifiers.

import Foundation
import Testing

@testable import InvariantSwiftCore
@testable import InvariantSwift

@Suite("Shrink Combinator Tests")
struct ShrinkCombinatorTests {

  // MARK: - Shrink.towards Tests (BinaryInteger)

  @Test("towards shrinks positive integer toward zero")
  func testTowardsPositiveToZero() {
    let candidates = Shrink<Int>.towards(0, 100)

    // Should include 0 (target) first
    #expect(candidates.first == 0)

    // Should include binary search candidates
    #expect(candidates.contains(50))

    // Should be ordered by simplicity (closest to target first after target)
    #expect(candidates.count >= 3)
  }

  @Test("towards shrinks negative integer toward zero")
  func testTowardsNegativeToZero() {
    let candidates = Shrink<Int>.towards(0, -100)

    // Should include 0 (target) first
    #expect(candidates.first == 0)

    // Should include binary search candidates
    #expect(candidates.contains(-50))
  }

  @Test("towards returns empty for value equal to target")
  func testTowardsValueEqualsTarget() {
    let candidates = Shrink<Int>.towards(50, 50)
    #expect(candidates.isEmpty)
  }

  @Test("towards shrinks toward non-zero target")
  func testTowardsNonZeroTarget() {
    let candidates = Shrink<Int>.towards(50, 100)

    // Should include 50 (target) first
    #expect(candidates.first == 50)

    // Should include intermediate values
    #expect(candidates.contains(75))
  }

  @Test("towards handles small values")
  func testTowardsSmallValues() {
    let candidates = Shrink<Int>.towards(0, 3)

    #expect(candidates.first == 0)
    #expect(candidates.contains(1) || candidates.contains(2))
  }

  @Test("towards handles value of 1")
  func testTowardsOne() {
    let candidates = Shrink<Int>.towards(0, 1)

    #expect(candidates.first == 0)
    // Only 0 is the valid shrink for 1 toward 0
  }

  // MARK: - Shrink.towards Tests (BinaryFloatingPoint)

  @Test("towards shrinks floating point toward zero")
  func testTowardsFloatToZero() {
    let candidates = Shrink<Double>.towards(0.0, 100.0)

    #expect(candidates.first == 0.0)
    #expect(candidates.contains(50.0))
  }

  @Test("towards shrinks negative float toward zero")
  func testTowardsNegativeFloatToZero() {
    let candidates = Shrink<Double>.towards(0.0, -100.0)

    #expect(candidates.first == 0.0)
    #expect(candidates.contains(-50.0))
  }

  @Test("towards returns empty for float equal to target")
  func testTowardsFloatEqualsTarget() {
    let candidates = Shrink<Double>.towards(3.14, 3.14)
    #expect(candidates.isEmpty)
  }

  // MARK: - Shrink.removeElements Tests

  @Test("removeElements returns empty for empty array")
  func testRemoveElementsEmpty() {
    let candidates = Shrink<Int>.removeElements(from: [])
    #expect(candidates.isEmpty)
  }

  @Test("removeElements includes empty array first")
  func testRemoveElementsIncludesEmpty() {
    let candidates = Shrink<Int>.removeElements(from: [1, 2, 3])

    // Empty array should be first (most aggressive shrink)
    #expect(candidates.first == [])
  }

  @Test("removeElements includes halves for multi-element arrays")
  func testRemoveElementsIncludesHalves() {
    let candidates = Shrink<Int>.removeElements(from: [1, 2, 3, 4])

    // Should include halves
    #expect(candidates.contains([3, 4]))  // Second half
    #expect(candidates.contains([1, 2]))  // First half
  }

  @Test("removeElements includes single element removals")
  func testRemoveElementsIndividual() {
    let candidates = Shrink<Int>.removeElements(from: [1, 2, 3])

    #expect(candidates.contains([2, 3]))  // Remove first
    #expect(candidates.contains([1, 3]))  // Remove middle
    #expect(candidates.contains([1, 2]))  // Remove last
  }

  @Test("removeElements for single element array")
  func testRemoveElementsSingleElement() {
    let candidates = Shrink<Int>.removeElements(from: [42])

    // Should include empty
    #expect(candidates.contains([]))
    // No halves for single element
  }

  // MARK: - Shrink.shrinkElements Tests

  @Test("shrinkElements applies shrinker to each element")
  func testShrinkElementsAppliesShrinker() {
    let intShrinker: (Int) -> [Int] = { value in
      Array(Shrink<Int>.towards(0, value))
    }

    let candidates = Shrink<Int>.shrinkElements(in: [10, 20], using: intShrinker)

    // Should include arrays with first element shrunk
    #expect(candidates.contains([0, 20]))
    #expect(candidates.contains([5, 20]))

    // Should include arrays with second element shrunk
    #expect(candidates.contains([10, 0]))
    #expect(candidates.contains([10, 10]))
  }

  @Test("shrinkElements returns empty for empty array")
  func testShrinkElementsEmpty() {
    let intShrinker: (Int) -> [Int] = { _ in [0] }
    let candidates = Shrink<Int>.shrinkElements(in: [], using: intShrinker)
    #expect(candidates.isEmpty)
  }

  @Test("shrinkElements handles empty shrinker results")
  func testShrinkElementsNoShrinks() {
    let noShrinkShrinker: (Int) -> [Int] = { _ in [] }
    let candidates = Shrink<Int>.shrinkElements(in: [1, 2, 3], using: noShrinkShrinker)
    #expect(candidates.isEmpty)
  }

  // MARK: - Shrink.concat Tests

  @Test("concat combines multiple strategies")
  func testConcatCombinesStrategies() {
    let strategy1: ([Int]) -> [[Int]] = { arr in
      Array(Shrink<Int>.removeElements(from: arr))
    }
    let strategy2: ([Int]) -> [[Int]] = { arr in
      Array(Shrink<Int>.shrinkElements(in: arr, using: { Array(Shrink<Int>.towards(0, $0)) }))
    }

    let combined = Shrink<[Int]>.concat([strategy1, strategy2])
    let candidates = combined([10, 20])

    // Should include results from strategy1 (removeElements)
    #expect(candidates.contains([]))
    #expect(candidates.contains([20]))
    #expect(candidates.contains([10]))

    // Should include results from strategy2 (shrinkElements)
    #expect(candidates.contains([0, 20]))
    #expect(candidates.contains([10, 0]))
  }

  @Test("concat with empty strategies returns empty")
  func testConcatEmptyStrategies() {
    let combined: (Int) -> [Int] = Shrink<Int>.concat([])
    let candidates = combined(100)
    #expect(candidates.isEmpty)
  }

  @Test("concat preserves order")
  func testConcatPreservesOrder() {
    let strategy1: (Int) -> [Int] = { _ in [1, 2] }
    let strategy2: (Int) -> [Int] = { _ in [3, 4] }

    let combined = Shrink<Int>.concat([strategy1, strategy2])
    let candidates = combined(100)

    #expect(candidates == [1, 2, 3, 4])
  }

  // MARK: - Gen.withShrink Tests

  @Test("withShrink replaces shrinking strategy")
  func testWithShrinkReplacesStrategy() {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<100, using: &rng)
    }
    .withShrink { value in
      [0, value / 2]
    }

    // Test that shrinking works
    let shrunk = gen.shrink.shrink(100)
    #expect(shrunk.contains(0))
    #expect(shrunk.contains(50))
  }

  @Test("withShrink preserves generation")
  func testWithShrinkPreservesGeneration() {
    let seed = Seed(value: 12345)
    let size = Size(value: 50)

    let originalGen = Gen<Int> { rng, _ in
      Int.random(in: 0..<100, using: &rng)
    }

    let modifiedGen = originalGen.withShrink { _ in [0] }

    // Both should generate the same value with same seed
    let original = originalGen.sample(size: size, seed: seed)
    let modified = modifiedGen.sample(size: size, seed: seed)

    #expect(original == modified)
  }

  @Test("withShrink can use Shrink.towards")
  func testWithShrinkWithTowards() {
    struct PositiveInt {
      let value: Int
    }

    let gen = Gen<Int> { rng, _ in
      Int.random(in: 1...100, using: &rng)
    }
    .map { PositiveInt(value: $0) }
    .withShrink { pos in
      Shrink<Int>.towards(1, pos.value)
        .filter { $0 > 0 }
        .map { PositiveInt(value: $0) }
    }

    let shrunk = gen.shrink.shrink(PositiveInt(value: 100))

    // Should shrink toward 1
    #expect(shrunk.first?.value == 1)
    #expect(shrunk.contains(where: { $0.value == 50 }))
  }

  // MARK: - Gen.noShrink Tests

  @Test("noShrink disables shrinking")
  func testNoShrinkDisables() {
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 0..<100, using: &rng)
    }
    .withShrink { value in [0, value / 2] }
    .noShrink()

    // Shrinking should return empty
    let shrunk = gen.shrink.shrink(100)
    #expect(shrunk.isEmpty)
  }

  @Test("noShrink preserves generation")
  func testNoShrinkPreservesGeneration() {
    let seed = Seed(value: 54321)
    let size = Size(value: 50)

    let originalGen = Gen<Int> { rng, _ in
      Int.random(in: 0..<100, using: &rng)
    }

    let noShrinkGen = originalGen.noShrink()

    // Both should generate the same value with same seed
    let original = originalGen.sample(size: size, seed: seed)
    let noShrink = noShrinkGen.sample(size: size, seed: seed)

    #expect(original == noShrink)
  }

  // MARK: - Integration Tests

  @Test("shrinking workflow: find minimal counterexample")
  func testShrinkingWorkflow() {
    // Property: array should have at least 3 elements
    let property: ([Int]) -> Bool = { arr in arr.count >= 3 }

    // Failing input: [1, 2] (only 2 elements)
    let failingInput = [1, 2]

    // This should already fail
    #expect(!property(failingInput))

    // A larger failing input
    let largerFailing = [10, 20]
    #expect(!property(largerFailing))

    // Shrink the larger failing input
    let shrinkFn: ([Int]) -> [[Int]] = Shrink<[Int]>.concat([
      { arr in Array(Shrink<Int>.removeElements(from: arr)) },
      { arr in
        Array(Shrink<Int>.shrinkElements(in: arr, using: { Array(Shrink<Int>.towards(0, $0)) }))
      },
    ])

    let candidates = shrinkFn(largerFailing)

    // Find smallest failing candidate
    let smallestFailing = candidates.filter { !property($0) }.min { $0.count < $1.count }

    // Should find empty array or smaller failing case
    #expect(smallestFailing != nil)
  }

  @Test("combined array shrinking strategy")
  func testCombinedArrayShrinking() {
    let intShrinker: (Int) -> [Int] = { Array(Shrink<Int>.towards(0, $0)) }

    let arrayShrink: ([Int]) -> [[Int]] = Shrink<[Int]>.concat([
      { Array(Shrink<Int>.removeElements(from: $0)) },
      { Array(Shrink<Int>.shrinkElements(in: $0, using: intShrinker)) },
    ])

    let candidates = arrayShrink([5, 10, 15])

    // From removeElements
    #expect(candidates.contains([]))
    #expect(candidates.contains([10, 15]))

    // From shrinkElements
    #expect(candidates.contains([0, 10, 15]))
    #expect(candidates.contains([5, 0, 15]))
  }
}
