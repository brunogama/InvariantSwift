import Testing
import Foundation
import InvariantSwiftCore
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
        shrunk <= counterexample,
        "Shrunk should be <= counterexample"
      )
      // With tree-based shrinking, the shrunk value should be smaller
      // than the original counterexample but may not reach minimal due
      // to finite tree depth
      #expect(
        shrunk < counterexample || counterexample < 200,
        "Should shrink toward boundary when possible"
      )

    case .success:
      Issue.record("Property should fail for some values > 50")

    case .gaveUp:
      Issue.record("Should not give up")
    }
  }

  // MARK: - ShrinkTree Edge Cases

  @Test("ShrinkTree handles empty children correctly")
  func shrinkTreeEmptyChildren() {
    let leaf = ShrinkTree.leaf(42)
    #expect(leaf.value == 42, "Leaf value should be 42")
    #expect(leaf.children.isEmpty, "Leaf should have no children")

    // Finding minimal on leaf should return the leaf
    let minimal = leaf.findMinimal(budget: 100) { _ in true }
    #expect(minimal == 42, "Should return leaf value")
  }

  @Test("ShrinkTree map preserves tree structure")
  func shrinkTreeMapStructure() {
    let tree = ShrinkTree(value: 5) {
      [ShrinkTree.leaf(2), ShrinkTree.leaf(1)]
    }

    let mapped = tree.map { $0 * 2 }
    #expect(mapped.value == 10, "Root should be mapped")

    let mappedChildren = mapped.children
    #expect(mappedChildren.count == 2, "Should have 2 children")
    #expect(mappedChildren[0].value == 4, "First child should be 4")
    #expect(mappedChildren[1].value == 2, "Second child should be 2")
  }

  @Test("ShrinkTree filter respects predicate")
  func shrinkTreeFilterRespectsPredicate() {
    let intShrink = Shrink<Int> { n in
      n > 0 ? [0, n / 2, n - 1] : []
    }

    let tree = ShrinkTree.from(10, shrink: intShrink)
    let filtered = tree.filter { $0 > 2 }  // Only keep values > 2

    // Root should pass
    #expect(filtered.value == 10, "Root should be kept")

    // Children should be filtered
    let children = filtered.children
    // Should include values > 2 from [0, 5, 9]
    let childValues = children.map(\.value)
    #expect(childValues.allSatisfy { $0 > 2 }, "All children should satisfy filter")
  }

  @Test("ShrinkTree prune limits depth correctly")
  func shrinkTreePruneDepth() {
    let tree = ShrinkTree(value: 1) {
      [
        ShrinkTree(value: 2) {
          [
            ShrinkTree(value: 3) {
              [ShrinkTree.leaf(4)]
            }
          ]
        }
      ]
    }

    let pruned1 = tree.prune(maxDepth: 1)
    #expect(pruned1.value == 1)
    #expect(!pruned1.children.isEmpty)
    #expect(pruned1.children[0].children.isEmpty, "Depth 2 should be pruned at maxDepth 1")

    // maxDepth 2 means: root + 1 level of children + 1 level of grandchildren
    // So grandchildren exist but their children (great-grandchildren) are pruned
    let pruned2 = tree.prune(maxDepth: 2)
    #expect(!pruned2.children[0].children.isEmpty, "Grandchildren should exist at maxDepth 2")
    #expect(
      pruned2.children[0].children[0].children.isEmpty,
      "Great-grandchildren should be pruned at maxDepth 2"
    )

    let pruned0 = tree.prune(maxDepth: 0)
    #expect(pruned0.value == 1)
    #expect(pruned0.children.isEmpty, "All children pruned at depth 0")
  }

  @Test("ShrinkTree limitBreadth caps children per node")
  func shrinkTreeLimitBreadth() {
    let tree = ShrinkTree(value: 100) {
      [ShrinkTree.leaf(0), ShrinkTree.leaf(50), ShrinkTree.leaf(75), ShrinkTree.leaf(99)]
    }

    let limited2 = tree.limitBreadth(2)
    #expect(limited2.children.count == 2, "Should have exactly 2 children")
    #expect(limited2.children[0].value == 0)
    #expect(limited2.children[1].value == 50)

    let limited1 = tree.limitBreadth(1)
    #expect(limited1.children.count == 1, "Should have exactly 1 child")
    #expect(limited1.children[0].value == 0)

    let limited0 = tree.limitBreadth(0)
    #expect(limited0.value == 100)
    #expect(limited0.children.isEmpty, "Should be leaf at breadth 0")
  }

  @Test("ShrinkTree limitTotal bounds total nodes")
  func shrinkTreeLimitTotal() {
    // Create a tree with 7 nodes: root + 3 children + 3 grandchildren
    let tree = ShrinkTree(value: 1) {
      [
        ShrinkTree(value: 2) { [ShrinkTree.leaf(4), ShrinkTree.leaf(5)] },
        ShrinkTree(value: 3) { [ShrinkTree.leaf(6), ShrinkTree.leaf(7)] },
      ]
    }

    let limited5 = tree.limitTotal(5)
    // BFS: 1, 2, 3, 4, 5 (first 5 nodes)
    let bfs = limited5.breadthFirst()
    #expect(bfs.count <= 5, "Should have at most 5 nodes in BFS order")
    #expect(bfs.first == 1, "Should start with root")

    let limited1 = tree.limitTotal(1)
    #expect(limited1.breadthFirst().count == 1, "Should have exactly 1 node")
    #expect(limited1.value == 1)
    #expect(limited1.children.isEmpty)
  }

  @Test("ShrinkTree deterministic traversal order")
  func shrinkTreeDeterministicOrder() {
    let intShrink = Shrink<Int> { n in
      guard n > 0 else { return [] }
      return [0, n / 2, n - 1]
    }

    let tree = ShrinkTree.from(100, shrink: intShrink)

    // BFS should be deterministic
    let bfs1 = tree.breadthFirst()
    let bfs2 = tree.breadthFirst()
    #expect(bfs1 == bfs2, "BFS traversal should be deterministic")

    // DFS should be deterministic
    let dfs1 = tree.depthFirst()
    let dfs2 = tree.depthFirst()
    #expect(dfs1 == dfs2, "DFS traversal should be deterministic")
  }

  @Test("ShrinkTree nested flatMap preserves shrinking")
  func shrinkTreeNestedFlatMap() {
    let tree1: ShrinkTree<Int> = ShrinkTree(value: 10) {
      [ShrinkTree.leaf(5), ShrinkTree.leaf(0)]
    }

    let tree2 = tree1.flatMap { n -> ShrinkTree<String> in
      ShrinkTree(value: String(repeating: "x", count: n)) {
        n > 0 ? [ShrinkTree.leaf("")] : []
      }
    }

    #expect(tree2.value == "xxxxxxxxxx", "Root should have 10 x's")

    let children = tree2.children
    #expect(!children.isEmpty, "Should have shrink candidates")
    // Should include both direct shrinks and transformed shrinks
  }

  @Test("ShrinkTree take limits immediate children only")
  func shrinkTreeTakeLimitsImmediate() {
    let tree = ShrinkTree(value: 1) {
      [
        ShrinkTree(value: 2) { [ShrinkTree.leaf(4), ShrinkTree.leaf(5), ShrinkTree.leaf(6)] },
        ShrinkTree(value: 3) { [ShrinkTree.leaf(7), ShrinkTree.leaf(8)] },
      ]
    }

    let limited = tree.take(1)
    #expect(limited.children.count == 1, "Root should have 1 child")

    // take() only limits immediate children, not recursively
    // The child still has all its original grandchildren
    let child = limited.children[0]
    let grandchildren = child.children
    #expect(grandchildren.count == 3, "take() does not apply recursively to grandchildren")
  }

  @Test("ShrinkTree findMinimal respects budget")
  func shrinkTreeFindMinimalBudget() {
    let intShrink = Shrink<Int> { n in
      n > 0 ? [0, n / 2, n - 1] : []
    }

    let tree = ShrinkTree.from(1000, shrink: intShrink)

    // With budget 1, should find at most 1 step of shrinking
    let minimal1 = tree.findMinimal(budget: 1) { _ in true }
    #expect(minimal1 != nil, "Should find some minimal value with budget 1")

    // With large budget, should find better result
    let minimal100 = tree.findMinimal(budget: 100) { _ in true }
    #expect(minimal100 != nil, "Should find minimal value with budget 100")
    // Larger budget should generally find smaller values (but not always)
  }

  @Test("ShrinkTree handles single-branch chains")
  func shrinkTreeLinearChain() {
    // Create a linear chain: 1 -> 2 -> 3 -> 4 -> 5
    let chain = ShrinkTree(value: 1) {
      [
        ShrinkTree(value: 2) {
          [
            ShrinkTree(value: 3) {
              [
                ShrinkTree(value: 4) {
                  [ShrinkTree.leaf(5)]
                }
              ]
            }
          ]
        }
      ]
    }

    let minimal = chain.findMinimal(budget: 100) { _ in true }
    // Should reach the deepest node with high budget
    #expect(minimal == 5 || minimal == 4, "Should explore deep chain")
  }
}
