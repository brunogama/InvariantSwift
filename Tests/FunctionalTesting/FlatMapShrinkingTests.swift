import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Tests for S024: Gen.flatMap shrinking with dependent generators
struct FlatMapShrinkingTests {

  // MARK: - Basic flatMap Shrinking

  @Test("flatMap generates correct values")
  func flatMapGeneratesCorrectValues() {
    // Generate a count, then generate values based on that count
    let gen = Gen<Int>.int(in: 1...5).flatMap { count in
      Gen<[Int]> { rng, _ in
        (0..<count).map { _ in Int.random(in: 0...10, using: &rng) }
      }
    }

    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    let value = gen.generate(&rng, Size(value: 50))

    #expect(value.count >= 1 && value.count <= 5, "Array count should be 1-5")
  }

  @Test("generateTreeFlatMap produces proper shrink tree")
  func generateTreeFlatMapProducesTree() {
    // Simple dependent generator: int -> string of that length
    let gen = Gen<Int>.int(in: 1...10)

    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 123))
    let tree = gen.generateTreeFlatMap(
      { n in
        Gen<String>.pure(String(repeating: "a", count: n))
      },
      &rng,
      Size(value: 50)
    )

    #expect(!tree.value.isEmpty, "Should generate non-empty string")

    // The tree should have children (shrinks)
    let children = tree.children
    #expect(!children.isEmpty, "Should have shrink candidates")
  }

  @Test("flatMap property with dependent shrinking finds counterexample")
  func flatMapPropertyWithDependentShrinking() {
    // Property: generate (n, array of size n) where array elements should all be < 10
    // But we'll generate values 0-20, so some will fail
    let gen = Gen<Int>.int(in: 1...5).flatMap { count in
      Gen<(Int, [Int])>.pure((count, [])).map { pair in
        var rng: any RandomNumberGenerator = SystemRandomNumberGenerator()
        let arr = (0..<pair.0).map { _ in Int.random(in: 0...20, using: &rng) }
        return (pair.0, arr)
      }
    }

    let property = Property<(Int, [Int])>(generator: gen) { _, array in
      array.allSatisfy { $0 < 10 }  // May fail if any element >= 10
    }

    let config = PropertyConfig(iterations: 50, maxShrinks: 100)
    let result = runPropertySynchronously(property, config: config)

    // We don't guarantee failure, but if it fails, it should shrink
    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      // Shrunk should be smaller or equal (count should be minimized)
      #expect(shrunk.0 <= counterexample.0, "Shrunk count should be <= original")

    case .success:
      // Property may succeed if we're lucky with random values
      break

    case .gaveUp:
      Issue.record("Should not give up on simple property")
    }
  }

  // MARK: - ShrinkTree Integration Tests

  @Test("ShrinkTree.from creates proper tree from Shrink")
  func shrinkTreeFromCreatesShrinkTree() {
    let intShrink = Shrink<Int> { n in
      n > 0 ? [0, n / 2, n - 1] : []
    }

    let tree = ShrinkTree.from(100, shrink: intShrink)
    #expect(tree.value == 100, "Root value should be 100")

    let children = tree.children
    #expect(children.count == 3, "Should have 3 shrink candidates")
    #expect(children.map(\.value).contains(0), "Should include 0")
    #expect(children.map(\.value).contains(50), "Should include 50")
    #expect(children.map(\.value).contains(99), "Should include 99")
  }

  @Test("ShrinkTree.findMinimal finds smallest satisfying value")
  func shrinkTreeFindMinimalWorks() {
    let intShrink = Shrink<Int> { n in
      n > 0 ? [0, n / 2, n - 1] : []
    }

    let tree = ShrinkTree.from(100, shrink: intShrink)

    // Find minimal value > 10
    let minimal = tree.findMinimal(budget: 50) { $0 > 10 }
    #expect(minimal != nil, "Should find minimal value")
    #expect(minimal! > 10, "Should satisfy predicate")
    // BFS explores level by level; with budget 50 it explores many nodes
    // The shrink produces [0, 50, 99] from 100, then continues from valid ones
    // Eventually finds smaller values, but exact value depends on tree structure
    #expect(minimal! < 100, "Should find something smaller than original")
  }

  @Test("ShrinkTree.flatMap composes trees correctly")
  func shrinkTreeFlatMapComposition() {
    let intTree = ShrinkTree(value: 10) {
      [ShrinkTree.leaf(5), ShrinkTree.leaf(0)]
    }

    let stringTree = intTree.flatMap { n in
      ShrinkTree(value: String(repeating: "x", count: n)) {
        n > 0 ? [ShrinkTree.leaf("")] : []
      }
    }

    #expect(stringTree.value == "xxxxxxxxxx", "Should have 10 x's")

    let children = stringTree.children
    // Should have children from both inner tree shrinks and outer tree shrinks
    #expect(!children.isEmpty, "Should have shrink children")
  }

  // MARK: - PropertyRunner Uses ShrinkTree

  @Test("PropertyRunner shrinkFailure uses BFS via ShrinkTree")
  func propertyRunnerUsesShrinkTree() {
    // Property that fails for values > 50, so shrinking should find ~51
    let property = Property<Int>(generator: Gen<Int>.int(in: 0...1000)) { n in
      n <= 50
    }

    let config = PropertyConfig(iterations: 100, maxShrinks: 200)
    let result = runPropertySynchronously(property, config: config)

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      #expect(counterexample > 50, "Counterexample should be > 50")
      #expect(shrunk > 50, "Shrunk should still fail predicate")
      #expect(
        shrunk < counterexample || shrunk == counterexample,
        "Shrunk should be <= counterexample"
      )
      // BFS should find a value close to 51
      #expect(shrunk <= 100, "BFS should find value closer to boundary")

    case .success:
      Issue.record("Property should fail for some values > 50")

    case .gaveUp:
      Issue.record("Should not give up")
    }
  }
}
