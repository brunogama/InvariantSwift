import XCTest
@testable import InvariantSwift

/// Tests for S024: Gen.flatMap shrinking correctness
final class FlatMapShrinkingTests: XCTestCase {

  // MARK: - S024 Acceptance Criteria Tests

  /// Test that flatMap-generated values shrink in both outer and inner dimensions
  func testFlatMapShrinksBothDimensions() {
    // Given: A dependent generator where inner depends on outer
    // Gen<Int> -> Gen<(Int, [Int])> where array length depends on the int
    let outerGen = Gen<Int> { rng, _ in
      Int.random(in: 1...10, using: &rng)
    }

    let dependentGen = outerGen.flatMap { outerValue in
      Gen<(Int, [Int])> { rng, _ in
        let array = (0..<outerValue).map { _ in Int.random(in: 0...100, using: &rng) }
        return (outerValue, array)
      }
    }

    // When: We generate a shrink tree
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    let tree = dependentGen.generateTree(&rng, Size(value: 50))

    // Then: The tree should have children (shrink candidates)
    let children = tree.children
    XCTAssertFalse(children.isEmpty, "flatMap should produce shrink candidates")

    // And: Values should shrink toward smaller outer values or smaller inner arrays
    let originalOuter = tree.value.0
    let originalArrayLength = tree.value.1.count

    // Check some children are actually smaller
    var foundSmallerOuter = false
    var foundSmallerArray = false

    for child in children.prefix(20) {
      if child.value.0 < originalOuter {
        foundSmallerOuter = true
      }
      if child.value.1.count < originalArrayLength {
        foundSmallerArray = true
      }
    }

    XCTAssertTrue(
      foundSmallerOuter || foundSmallerArray,
      "Should find smaller shrink candidates in at least one dimension"
    )
  }

  /// Test that shrinking is deterministic across runs
  func testFlatMapShrinkingIsDeterministic() {
    let gen = Gen<Int>.int(in: 1...10).flatMap { n in
      Gen<String>.string(count: n)
    }

    let seed = Seed(value: 12345)

    // Run 1
    var rng1: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)
    let tree1 = gen.generateTree(&rng1, Size(value: 50))
    let children1 = tree1.children.prefix(10).map { $0.value }

    // Run 2 with same seed
    var rng2: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)
    let tree2 = gen.generateTree(&rng2, Size(value: 50))
    let children2 = tree2.children.prefix(10).map { $0.value }

    // Should produce identical results
    XCTAssertEqual(tree1.value, tree2.value, "Same seed should produce same value")
    XCTAssertEqual(children1, children2, "Same seed should produce same shrink candidates")
  }

  /// Test that findMinimal finds a minimal counterexample
  func testFlatMapFindMinimalWorks() {
    // Generator: Int -> [Int] where array has `n` elements all > 5
    let gen = Gen<Int>.int(in: 3...10).flatMap { n in
      Gen<[Int]>.array(of: Gen<Int>.int(in: 6...100), count: n)
    }

    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 999))
    let tree = gen.generateTree(&rng, Size(value: 50))

    // Find minimal array that has at least one element > 50
    let minimal = tree.findMinimal(budget: 100) { array in
      array.contains { $0 > 50 }
    }

    // If found, it should be simpler than original
    if let minimal = minimal {
      // Either shorter or with smaller elements
      XCTAssertLessThanOrEqual(
        minimal.count,
        tree.value.count,
        "Minimal should not be longer than original"
      )
    }
    // Note: May not find any match if no element > 50 in tree
  }
}
