import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Phase 4 Generator Optimization Tests
///
/// These tests verify the optimizations in the generator engine:
/// - Lazy shrinking tree evaluation
/// - Concurrent shrinking support
/// - Primitive generator performance
/// - Memory efficiency for large structures
@Suite("Generator Optimization Tests")
struct GeneratorOptimizationTests {

  // MARK: - Lazy Shrinking Tree Tests

  @Test("Lazy shrinking tree preserves values")
  func lazyShrinkingTreePreservesValues() {
    let lazy = Lazy {
      [1, 2, 3, 4, 5]
    }

    // Value should be preserved on access
    let value1 = lazy.value
    let value2 = lazy.value
    #expect(value1 == value2, "Lazy should return consistent values")
    #expect(value1.count == 5)
  }

  @Test("Node map preserves lazy structure")
  func nodeMapPreservesLaziness() {
    let node = Node<Int>(value: 10) {
      [Node.leaf(5), Node.leaf(2), Node.leaf(0)]
    }

    let mapped = node.map { $0 * 2 }

    #expect(mapped.value == 20)
    #expect(mapped.shrinks.value.count == 3)
    #expect(mapped.shrinks.value[0].value == 10)
    #expect(mapped.shrinks.value[2].value == 0)
  }

  @Test("Node filter maintains shrink structure")
  func nodeFilterMaintainsStructure() {
    let node = Node<Int>(value: 10) {
      [Node.leaf(8), Node.leaf(5), Node.leaf(2), Node.leaf(-1)]
    }

    let filtered = node.filter { $0 >= 0 }

    #expect(filtered.value == 10)
    let shrinks = filtered.shrinks.value
    #expect(shrinks.allSatisfy { $0.value >= 0 })
  }

  @Test("Node.take limits shrink candidates for performance")
  func nodeTakeLimitsShrinks() {
    let node = Node<Int>(value: 100) {
      (0..<50).map { Node.leaf($0) }
    }

    let limited = node.take(5)
    #expect(limited.shrinks.value.count == 5)
    #expect(limited.shrinks.value[0].value == 0)
    #expect(limited.shrinks.value[4].value == 4)
  }

  @Test("Node.prune limits tree depth for performance")
  func nodePruneLimitsDepth() {
    // Create a tree with many shrinks
    let node = Node<Int>(value: 10) {
      (0..<10).map { i in
        Node<Int>(value: i) {
          (0..<5).map { j in
            Node.leaf(j)
          }
        }
      }
    }

    let pruned = node.prune(maxDepth: 1)

    // After pruning to depth 1, shrinks should be leaves
    for shrink in pruned.shrinks.value {
      #expect(shrink.shrinks.value.isEmpty, "Pruned shrinks should be leaves")
    }
  }

  // MARK: - TreeGen Performance Tests

  @Test("TreeGen.int generates integers with integrated shrinking")
  func treeGenIntGeneratesWithShrinking() {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    let gen = TreeGen<Int>.int(in: 1...100)
    let size = Size(value: 50)

    let node = gen.run(&rng, size)

    #expect(node.value >= 1 && node.value <= 100)
    #expect(!node.shrinks.value.isEmpty, "Should have shrink candidates")

    // Shrinks should be toward smaller values
    for shrink in node.shrinks.value.prefix(3) {
      #expect(
        abs(shrink.value) <= abs(node.value),
        "Shrink \(shrink.value) should be smaller than \(node.value)"
      )
    }
  }

  @Test("TreeGen.array integrates element shrinking")
  func treeGenArrayIntegratesElementShrinking() {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    let elementGen = TreeGen<Int>.int(in: 0...10)
    let arrayGen = TreeGen<[Int]>.array(of: elementGen, maxCount: 5)
    let size = Size(value: 10)

    let node = arrayGen.run(&rng, size)

    #expect(node.value.count <= 5)
    #expect(!node.shrinks.value.isEmpty, "Should have shrink candidates")

    // Should include empty array shrink
    let hasEmptyArrayShrink = node.shrinks.value.contains { $0.value.isEmpty }
    #expect(hasEmptyArrayShrink || node.value.isEmpty, "Should include empty array shrink")
  }

  // MARK: - ShrinkTreeRunner Tests

  @Test("ShrinkTreeRunner finds minimal counterexample")
  func shrinkTreeRunnerFindsMinimal() async throws {
    let gen = TreeGen<Int>.int(in: 50...200)

    let result = try await ShrinkTreeRunner.runProperty(
      generator: gen,
      iterations: 50,
      maxShrinkSteps: 100
    ) { value in
      value < 100  // Will fail for values >= 100
    }

    switch result {
    case .success:
      Issue.record("Property should fail")
    case .failure(let shrinkResult):
      #expect(shrinkResult.minimalCounterexample >= 100)
      #expect(shrinkResult.minimalCounterexample <= shrinkResult.originalValue)
      #expect(shrinkResult.shrinkSteps >= 0)
    }
  }

  // MARK: - Concurrent Shrinking Tests

  @Test("Concurrent shrinking with multiple properties")
  func concurrentShrinkingWithMultipleProperties() async {
    let properties: [Property<Int>] = (0..<4).map { i in
      Property<Int>(generator: Gen.int(in: 1...100)) { value in
        value < (50 + i * 10)  // Different thresholds
      }
    }

    let config = PropertyConfig(iterations: 50, maxShrinks: 50)

    // Run all properties concurrently
    await withTaskGroup(of: PropertyResult<Int>.self) { group in
      for property in properties {
        group.addTask {
          runPropertySynchronously(property, config: config)
        }
      }

      var results: [PropertyResult<Int>] = []
      for await result in group {
        results.append(result)
      }

      // All should complete (either success or failure with shrunk value)
      #expect(results.count == 4)
      for result in results {
        #expect(!result.isGaveUp, "Should not give up")
      }
    }
  }

  // MARK: - Primitive Generator Throughput

  @Test("Primitive generator throughput benchmark")
  func primitiveGeneratorThroughput() {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 42))
    let size = Size(value: 10)
    let iterations = 10000

    let startTime = CFAbsoluteTimeGetCurrent()

    for _ in 0..<iterations {
      _ = Gen.int.generate(&rng, size)
      _ = Gen.bool.generate(&rng, size)
      _ = Gen.double.generate(&rng, size)
    }

    let duration = CFAbsoluteTimeGetCurrent() - startTime
    let opsPerSecond = Double(iterations * 3) / duration

    #expect(opsPerSecond > 100_000, "Should achieve high throughput: \(opsPerSecond) ops/sec")
  }
}
