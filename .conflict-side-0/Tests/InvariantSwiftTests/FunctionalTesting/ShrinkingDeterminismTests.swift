import Testing
import Foundation
import InvariantSwiftCore
@testable import InvariantSwift

/// Tests for shrinking determinism - ensures shrinking produces consistent results
/// across runs with the same seed.
///
/// These tests are serialized because determinism assertions require sequential execution
/// to avoid async actor scheduling interference between parallel tests.
@Suite(.serialized)
struct ShrinkingDeterminismTests {

  // MARK: - Deterministic Shrinking

  @Test("Same seed produces identical shrunk counterexamples")
  func sameSeedProducesIdenticalShrinks() {
    // Property that fails for values > 50 - should shrink to 51
    let property = Property<Int>(generator: Gen<Int>.int(in: 0...1000)) { n in
      n <= 50
    }

    let seed = Seed(value: 42)
    let config = PropertyConfig(seed: seed)

    // Use synchronous runner helper to avoid async actor scheduling interference
    // during concurrent test execution
    let result1 = runPropertySynchronously(property, config: config)
    let result2 = runPropertySynchronously(property, config: config)

    // Both should produce identical shrunk counterexamples
    switch (result1, result2) {
    case (.failure(_, _, let shrunk1, _, _), .failure(_, _, let shrunk2, _, _)):
      #expect(shrunk1 == shrunk2, "Same seed should produce identical shrunk values")

    default:
      Issue.record("Expected both runs to produce failures")
    }
  }

  @Test("ShrinkTree findMinimal returns consistent results")
  func findMinimalIsDeterministic() {
    let intShrink = Shrink<Int> { n in
      n > 0 ? [0, n / 2, n - 1] : []
    }

    let tree = ShrinkTree.from(100, shrink: intShrink)

    // Run findMinimal multiple times
    let results = (0..<10).map { _ in
      tree.findMinimal(budget: 100) { $0 > 10 }
    }

    // All results should be identical (deterministic)
    let allEqual = results.allSatisfy { $0 == results[0] }
    #expect(allEqual, "findMinimal should be deterministic across calls")

    // The value should be > 10 (minimal satisfying predicate)
    if let result = results[0] {
      #expect(result > 10, "Result should satisfy the predicate (> 10)")
    }
  }

  @Test("BFS traversal order is deterministic")
  func bfsTraversalIsDeterministic() {
    let tree = ShrinkTree(value: 100) {
      [
        ShrinkTree(value: 50) { [ShrinkTree.leaf(25), ShrinkTree.leaf(0)] },
        ShrinkTree(value: 75) { [ShrinkTree.leaf(60)] },
        ShrinkTree.leaf(99),
      ]
    }

    // Run BFS multiple times
    let bfs1 = tree.breadthFirst()
    let bfs2 = tree.breadthFirst()
    let bfs3 = tree.breadthFirst()

    #expect(bfs1 == bfs2, "BFS should be deterministic")
    #expect(bfs2 == bfs3, "BFS should be deterministic")
    #expect(bfs1 == [100, 50, 75, 99, 25, 0, 60], "Expected BFS order")
  }

  // MARK: - Replay Token Determinism

  @Test("Replay token reproduces exact shrunk counterexample")
  func replayTokenReproducesShrinking() async {
    // Property that fails for values > 50
    let gen = Gen<Int>.int(in: 0...100)
    let property = Property<Int>(generator: gen) { n in
      n <= 50
    }

    let seed = Seed(value: 999)
    let runner = PropertyRunner(seed: seed)
    let originalResult = await runner.runProperty(property)

    guard case .failure(_, let iterations, let shrunk1, _, let resultSeed) = originalResult else {
      Issue.record("Expected failure")
      return
    }

    // Create replay token
    let token = ReplayToken(seed: resultSeed.rawValue, iterations: iterations)

    // Replay with the token
    let replayResult = await PropertyRunner.runFromToken(property, token: token)

    guard case .failure(_, _, let shrunk2, _, _) = replayResult else {
      Issue.record("Replay should also fail")
      return
    }

    #expect(shrunk1 == shrunk2, "Replay should produce identical shrunk value")
  }

  // MARK: - FlatMap Dependent Shrinking Determinism

  @Test("FlatMap shrinking is deterministic with same seed")
  func flatMapShrinkingIsDeterministic() async {
    // Dependent generator: count -> array of that size
    let gen: Gen<[Int]> = Gen<Int>.int(in: 1...5).flatMap { count in
      Gen<[Int]>.array(elementGen: Gen<Int>.int(in: 0...100), maxLength: count)
    }

    // Property fails when any element > 50
    let property = Property<[Int]>(generator: gen) { (arr: [Int]) in
      arr.allSatisfy { $0 <= 50 }
    }

    let seed = Seed(value: 123)

    // Run twice with same seed
    let runner1 = PropertyRunner(seed: seed)
    let result1 = await runner1.runProperty(property)

    let runner2 = PropertyRunner(seed: seed)
    let result2 = await runner2.runProperty(property)

    // Both runs should produce identical results
    switch (result1, result2) {
    case (
      .failure(let ce1, let iter1, let shrunk1, _, _),
      .failure(let ce2, let iter2, let shrunk2, _, _)
    ):
      #expect(ce1 == ce2, "Same counterexamples with same seed")
      #expect(iter1 == iter2, "Same iteration count with same seed")
      #expect(shrunk1 == shrunk2, "Same shrunk value with same seed")

    case (.success, .success):
      // Both passed is also deterministic
      break

    default:
      Issue.record("Results should be identical with same seed")
    }
  }

  // MARK: - Throwing Property Shrinking

  @Test("Throwing property shrinking is deterministic")
  func throwingPropertyShrinkingIsDeterministic() async {
    struct TestError: Error {}

    let property = ThrowingProperty<Int>(generator: Gen<Int>.int(in: 0...100)) { n in
      if n > 50 { throw TestError() }
      return true
    }

    let seed = Seed(value: 456)

    let runner1 = PropertyRunner(seed: seed)
    let result1 = await runner1.runThrowingProperty(property)

    let runner2 = PropertyRunner(seed: seed)
    let result2 = await runner2.runThrowingProperty(property)

    switch (result1, result2) {
    case (.failure(_, _, let shrunk1, _, _), .failure(_, _, let shrunk2, _, _)):
      #expect(shrunk1 == shrunk2, "Throwing property shrinking should be deterministic")

    default:
      Issue.record("Expected both runs to produce failures")
    }
  }

  // MARK: - Evaluating Property Shrinking

  @Test("Evaluating property shrinking is deterministic")
  func evaluatingPropertyShrinkingIsDeterministic() async {
    let property = EvaluatingProperty<Int>(generator: Gen<Int>.int(in: 0...100)) { n in
      if n > 50 {
        return .fail(reason: "too large")
      }
      return .pass
    }

    let seed = Seed(value: 789)

    let runner1 = PropertyRunner(seed: seed)
    let result1 = await runner1.runEvaluatingProperty(property)

    let runner2 = PropertyRunner(seed: seed)
    let result2 = await runner2.runEvaluatingProperty(property)

    switch (result1, result2) {
    case (.failure(_, _, let shrunk1, _, _), .failure(_, _, let shrunk2, _, _)):
      #expect(shrunk1 == shrunk2, "Evaluating property shrinking should be deterministic")

    default:
      Issue.record("Expected both runs to produce failures")
    }
  }
}
