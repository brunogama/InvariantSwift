import InvariantSwiftCore
import Testing

@Suite("ShrinkTree Search Tests")
struct ShrinkTreeSearchTests {

  @Test("findMinimal preserves earlier simpler siblings")
  func findMinimalPreservesSiblingOrder() {
    let tree = ShrinkTree(value: 150) {
      [
        ShrinkTree.leaf(100),
        ShrinkTree(value: 125) {
          [ShrinkTree.leaf(100), ShrinkTree.leaf(112), ShrinkTree.leaf(124)]
        },
        ShrinkTree(value: 149) {
          [ShrinkTree.leaf(100), ShrinkTree.leaf(124), ShrinkTree.leaf(148)]
        },
      ]
    }

    let minimal = tree.findMinimal(budget: 100) { $0 >= 100 }

    #expect(minimal == 100, "Search should keep the earliest simpler sibling")
  }

  @Test("parallel search preserves earlier simpler siblings")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func parallelSearchPreservesSiblingOrder() async {
    let tree = ShrinkTree(value: 150) {
      [
        ShrinkTree.leaf(100),
        ShrinkTree(value: 125) {
          [ShrinkTree.leaf(100), ShrinkTree.leaf(112), ShrinkTree.leaf(124)]
        },
        ShrinkTree(value: 149) {
          [ShrinkTree.leaf(100), ShrinkTree.leaf(124), ShrinkTree.leaf(148)]
        },
      ]
    }

    let minimal = await tree.findMinimalParallel(budget: 100, workers: 2) { $0 >= 100 }

    #expect(minimal == 100, "Parallel search should preserve sibling order")
  }
}
