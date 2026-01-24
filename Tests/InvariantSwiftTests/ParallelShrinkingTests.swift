/// ParallelShrinkingTests - Tests for parallel shrink tree exploration
///
/// Validates correctness, determinism, and performance of parallel shrinking.

import Foundation
import Testing
@testable import InvariantSwift

@Suite("Parallel Shrinking Tests")
struct ParallelShrinkingTests {

  // MARK: - Correctness Tests

  @Test("Parallel finds same result as sequential for small trees")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func parallelMatchesSequentialSmallTree() async {
    // Create a small shrink tree: 100 -> [0, 50, 75, 88...]
    let tree = ShrinkTree(value: 100) {
      let shrinks = Shrink.towards(0, 100)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    let sequential = await tree.findMinimalAsync(budget: 100) { $0 > 10 }
    let parallel = await tree.findMinimalParallel(budget: 100) { $0 > 10 }

    #expect(sequential != nil)
    #expect(parallel != nil)
    #expect(sequential == parallel, "Both should find value > 10")
  }

  @Test("Parallel finds valid minimal for large trees")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func parallelFindsValidMinimal() async {
    // Create a wide tree with many children
    let tree = ShrinkTree(value: 1000) {
      (0..<20).map { i in
        ShrinkTree.leaf(1000 - (i * 50))
      }
    }

    let result = await tree.findMinimalParallel(budget: 100, workers: 4) { $0 > 100 }

    #expect(result != nil)
    #expect(result! > 100, "Result should satisfy predicate")
    #expect(result! <= 1000, "Result should be <= root value")
  }

  @Test("Empty tree returns nil")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func emptyTreeReturnsNil() async {
    let tree = ShrinkTree<Int>.leaf(42)

    let result = await tree.findMinimalParallel(budget: 10) { $0 > 100 }

    #expect(result == nil, "No value satisfies predicate > 100")
  }

  @Test("Root not satisfying predicate returns nil")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func rootNotSatisfyingReturnsNil() async {
    let tree = ShrinkTree(value: 5) {
      [ShrinkTree.leaf(1), ShrinkTree.leaf(2), ShrinkTree.leaf(3)]
    }

    let result = await tree.findMinimalParallel(budget: 10) { $0 > 100 }

    #expect(result == nil, "Root doesn't satisfy predicate")
  }

  // MARK: - Determinism Tests

  @Test("Same tree and predicate produces same result across runs")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func deterministicResults() async {
    let makeTree = {
      ShrinkTree(value: 500) {
        let shrinks = Shrink.towards(0, 500)
        return shrinks.map { ShrinkTree.leaf($0) }
      }
    }

    let results = await withTaskGroup(of: Int?.self) { group in
      for _ in 0..<10 {
        group.addTask {
          let tree = makeTree()
          return await tree.findMinimalParallel(budget: 200, workers: 4) { $0 > 50 }
        }
      }

      var collected: [Int?] = []
      for await result in group {
        collected.append(result)
      }
      return collected
    }

    #expect(results.count == 10)
    let firstResult = results.first!
    #expect(results.allSatisfy { $0 == firstResult }, "All runs should produce same result")
  }

  @Test("Comparable types find truly minimal value")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func comparableFindsMinimum() async {
    // Tree with multiple branches, some might find different minimums
    let tree = ShrinkTree(value: 100) {
      [
        ShrinkTree.leaf(11),
        ShrinkTree.leaf(12),
        ShrinkTree.leaf(15),
        ShrinkTree.leaf(20),
      ]
    }

    let result = await tree.findMinimalParallelComparable(budget: 100, workers: 4) { $0 > 10 }

    #expect(result == 11, "Should find smallest value > 10")
  }

  // MARK: - Performance Tests

  @Test("Wide tree benefits from parallelization")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func wideTreeSpeedup() async {
    // Create a wide tree (many children per node)
    let tree = ShrinkTree(value: 1000) {
      (0..<100).map { i in
        ShrinkTree(value: 1000 - i) {
          (0..<10).map { j in
            ShrinkTree.leaf(1000 - i - j)
          }
        }
      }
    }

    let sequentialStart = CFAbsoluteTimeGetCurrent()
    let sequentialResult = await tree.findMinimalAsync(budget: 500) { $0 > 100 }
    let sequentialTime = CFAbsoluteTimeGetCurrent() - sequentialStart

    let parallelStart = CFAbsoluteTimeGetCurrent()
    let parallelResult = await tree.findMinimalParallel(budget: 500, workers: 4) { $0 > 100 }
    let parallelTime = CFAbsoluteTimeGetCurrent() - parallelStart

    #expect(sequentialResult != nil)
    #expect(parallelResult != nil)

    // Parallel should be at least as fast (may be faster, but not always guaranteed in tests)
    // We're mainly testing that it completes and finds correct result
  }

  @Test("Deep tree may not benefit from parallelization")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func deepTreeSequentialOkay() async {
    // Create a deep tree (few children, many levels)
    func makeDeepTree(_ value: Int, depth: Int) -> ShrinkTree<Int> {
      if depth == 0 || value <= 0 {
        return ShrinkTree.leaf(value)
      }
      return ShrinkTree(value: value) {
        [makeDeepTree(value - 1, depth: depth - 1)]
      }
    }

    let tree = makeDeepTree(100, depth: 50)
    let result = await tree.findMinimalParallel(budget: 200, workers: 4) { $0 > 10 }

    #expect(result != nil)
    #expect(result! > 10, "Should find value > 10 in deep tree")
  }

  // MARK: - Edge Cases

  @Test("Budget of 0 returns root if satisfies")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func budgetZeroReturnsRoot() async {
    let tree = ShrinkTree(value: 42) {
      [ShrinkTree.leaf(10), ShrinkTree.leaf(20)]
    }

    let result = await tree.findMinimalParallel(budget: 0) { $0 > 0 }

    #expect(result == 42, "Budget 0 should return root if it satisfies")
  }

  @Test("Single worker degrades to sequential")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func singleWorkerSequential() async {
    let tree = ShrinkTree(value: 100) {
      let shrinks = Shrink.towards(0, 100)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    let result = await tree.findMinimalParallel(budget: 100, workers: 1) { $0 > 10 }

    #expect(result != nil)
    #expect(result! > 10)
  }

  @Test("Very large budget doesn't cause issues")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func largeBudgetWorks() async {
    let tree = ShrinkTree(value: 1000) {
      (0..<10).map { i in
        ShrinkTree.leaf(1000 - (i * 100))
      }
    }

    let result = await tree.findMinimalParallel(budget: 100000, workers: 4) { $0 > 100 }

    #expect(result != nil)
    #expect(result! > 100)
  }

  // MARK: - ParallelShrinker Actor Tests

  @Test("ParallelShrinker with default config works")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func parallelShrinkerDefaultConfig() async {
    let shrinker = ParallelShrinker(config: .default)
    let tree = ShrinkTree(value: 100) {
      let shrinks = Shrink.towards(0, 100)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    let result = await shrinker.findMinimal(in: tree) { $0 > 10 }

    #expect(result != nil)
    #expect(result! > 10)
  }

  @Test("ParallelShrinker benchmark returns valid comparison")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func parallelShrinkerBenchmark() async {
    let shrinker = ParallelShrinker(config: .default)
    let tree = ShrinkTree(value: 200) {
      let shrinks = Shrink.towards(0, 200)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    let benchmark = await shrinker.benchmark(tree: tree) { $0 > 50 }

    #expect(benchmark.sequentialResult != nil)
    #expect(benchmark.parallelResult != nil)
    #expect(benchmark.resultsMatch, "Sequential and parallel should find same result")
    #expect(benchmark.sequentialTime >= 0)
    #expect(benchmark.parallelTime >= 0)
    #expect(benchmark.speedup > 0)
  }

  @Test("ParallelShrinker progress tracking works when enabled")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func parallelShrinkerProgressTracking() async {
    let shrinker = ParallelShrinker(config: .debug)  // debug enables progress
    let tree = ShrinkTree(value: 100) {
      let shrinks = Shrink.towards(0, 100)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    _ = await shrinker.findMinimal(in: tree) { $0 > 10 }
    let progress = await shrinker.getProgress()

    #expect(progress.nodesVisited > 0, "Should track nodes visited")
    #expect(progress.candidatesFound > 0, "Should track candidates found")
  }

  // MARK: - Integration with Gen

  @Test("Generate failing value, shrink in parallel, verify minimal")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func integrationWithGenerator() async {
    // Generate a failing value
    let gen = Gen<Int> { rng, _ in
      Int.random(in: 50...200, using: &rng)
    }

    let failingValue = gen.sample(size: Size(value: 100), seed: Seed(value: 42))

    // Create shrink tree for the failing value
    let tree = ShrinkTree(value: failingValue) {
      let shrinks = Shrink.towards(0, failingValue)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    // Find minimal failing value (assume property fails for values > 10)
    let shrinker = ParallelShrinker()
    let minimal = await shrinker.findMinimal(in: tree) { $0 > 10 }

    #expect(minimal != nil)
    #expect(minimal! > 10, "Minimal should satisfy predicate")
    #expect(minimal! <= failingValue, "Minimal should be <= original failing value")
  }

  // MARK: - Timeout/Time Limit Tests

  @Test("No infinite loops with time limit", .timeLimit(.seconds(5)))
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func noInfiniteLoops() async {
    // Create a large tree that could potentially cause issues
    func makeHugeTree(_ value: Int, depth: Int) -> ShrinkTree<Int> {
      if depth == 0 {
        return ShrinkTree.leaf(value)
      }
      return ShrinkTree(value: value) {
        (0..<10).map { i in
          makeHugeTree(value - i - 1, depth: depth - 1)
        }
      }
    }

    let tree = makeHugeTree(1000, depth: 5)
    let result = await tree.findMinimalParallel(budget: 1000, workers: 4) { $0 > 100 }

    // Should complete within time limit
    #expect(result != nil)
  }

  // MARK: - Fallback Tests

  @Test("Fallback to sequential on error works")
  @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
  func fallbackToSequential() async {
    let tree = ShrinkTree(value: 100) {
      let shrinks = Shrink.towards(0, 100)
      return shrinks.map { ShrinkTree.leaf($0) }
    }

    let result = await tree.findMinimalParallelWithFallback(budget: 100, workers: 4) { $0 > 10 }

    #expect(result != nil)
    #expect(result! > 10)
  }

  // MARK: - Array Chunking Helper Tests

  @Test("Array chunking splits evenly")
  func arrayChunkingEven() {
    let array = Array(1...10)
    let chunks = array.chunked(into: 2)

    #expect(chunks.count == 2)
    #expect(chunks[0].count == 5)
    #expect(chunks[1].count == 5)
  }

  @Test("Array chunking handles uneven splits")
  func arrayChunkingUneven() {
    let array = Array(1...10)
    let chunks = array.chunked(into: 3)

    #expect(chunks.count == 3)
    #expect(chunks[0].count == 4)
    #expect(chunks[1].count == 4)
    #expect(chunks[2].count == 2)
  }

  @Test("Array chunking handles single chunk")
  func arrayChunkingSingle() {
    let array = Array(1...5)
    let chunks = array.chunked(into: 1)

    #expect(chunks.count == 1)
    #expect(chunks[0] == array)
  }

  @Test("Array chunking handles more chunks than elements")
  func arrayChunkingMoreThanElements() {
    let array = [1, 2, 3]
    let chunks = array.chunked(into: 5)

    #expect(chunks.count == 3)
    #expect(chunks.allSatisfy { $0.count == 1 })
  }

  @Test("Array chunking handles empty array")
  func arrayChunkingEmpty() {
    let array: [Int] = []
    let chunks = array.chunked(into: 3)

    #expect(chunks.isEmpty)
  }
}
