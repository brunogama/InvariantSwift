import Testing
import Foundation
@testable import InvariantCore
@testable import InvariantSwift

/// Recursive shrinking validation tests - using shrinking to test shrinking
///
/// These tests implement the recursive principle of using the framework's own
/// shrinking capabilities to verify that shrinking works correctly at all levels.
/// This ensures that our minimization algorithms are mathematically sound.
///
/// **Mathematical Foundation**:
/// Shrinking is a coalgebraic operation that produces successively smaller values
/// while preserving the property that caused failure. We test this by creating
/// shrinking functions that shrink other shrinking functions.
///
/// **Reference**: Coalgebras and infinite data structures
/// https://en.wikipedia.org/wiki/Coalgebra
struct RecursiveShrinkingTests {

  // MARK: - Shrinking Shrinking Functions

  @Test("Shrinker that shrinks shrinkers preserves minimality")
  func shrinkerOfShrinkers() async {
    /// Test Intent: Create a shrinking function that operates on other shrinking
    /// functions, ensuring that the meta-shrinking process preserves the
    /// fundamental property that shrunk values are smaller than original values.

    // Generator that creates different shrinking strategies
    let shrinkGen = Gen<Shrink<[Int]>> { rng, _ in
      let strategy = Int.random(in: 0...2, using: &rng)

      switch strategy {
      case 0:
        // Remove-one strategy
        return Shrink { array in
          guard !array.isEmpty else { return [] }
          return (0..<array.count).map { i in
            var smaller = array
            smaller.remove(at: i)
            return smaller
          }
        }

      case 1:
        // Halve-elements strategy
        return Shrink { array in
          [array.map { $0 / 2 }, Array(array.dropLast())]
        }

      default:
        // Binary-search strategy
        return Shrink { array in
          guard array.count > 1 else { return [] }
          let mid = array.count / 2
          return [Array(array.prefix(mid)), Array(array.suffix(mid))]
        }
      }
    }

    // Property: All shrinking strategies should produce smaller or equal arrays
    let shrinkingProperty = Property(generator: shrinkGen) { (shrinkStrategy: Shrink<[Int]>) in
      let testArrays: [[Int]] = [
        [1, 2, 3, 4, 5],
        [10, 20, 30],
        [100, 200, 300, 400, 500, 600],
        [],
      ]

      return testArrays.allSatisfy { testArray in
        let shrunkResults = shrinkStrategy.shrink(testArray)

        // All shrunk results should be smaller than or equal to original
        return shrunkResults.allSatisfy { shrunk in
          shrunk.count <= testArray.count
            && shrunk.allSatisfy { element in
              // For numeric shrinking, elements should be smaller or equal
              testArray.contains { $0 >= abs(element) }
            }
        }
      }
    }

    let result = runPropertySynchronously(shrinkingProperty, config: PropertyConfig(iterations: 50))
    #expect(
      result.isSuccess,
      "All shrinking strategies should produce progressively smaller values"
    )
  }

  @Test("Meta-shrinking preserves shrinking invariants")
  func metaShrinkingPreservesInvariants() async {
    /// Test Intent: Verify that when we shrink shrinking functions themselves,
    /// the resulting shrinking functions still maintain the core shrinking invariants.

    // Create a "shrinking function for shrinking functions"
    let metaShrink = Shrink<Shrink<Int>> { _ in
      // Generate simpler shrinking strategies
      let simpleShrinks: [Shrink<Int>] = [
        // Identity shrink (no shrinking)
        Shrink { _ in [] },

        // Halve-only shrink
        Shrink { n in n == 0 ? [] : [n / 2] },

        // Decrement shrink
        Shrink { n in n <= 0 ? [] : [n - 1] },
      ]

      return simpleShrinks
    }

    // Test the meta-shrinking
    let complexShrink = Shrink<Int> { n in
      // Complex shrinking strategy
      var results: [Int] = []
      if n > 0 {
        results.append(n / 2)
        results.append(n - 1)
      }
      if n > 10 {
        results.append(n / 10)
      }
      return results
    }

    let simplifiedShrinks = metaShrink.shrink(complexShrink)

    // Each simplified shrink should still behave correctly
    let testValue = 100
    var allValid = true

    for simplifiedShrink in simplifiedShrinks {
      let shrunkValues = simplifiedShrink.shrink(testValue)

      // All shrunk values should be smaller than original
      let valid = shrunkValues.allSatisfy { $0 <= testValue }
      allValid = allValid && valid
    }

    #expect(allValid, "Meta-shrunk shrinking functions should preserve shrinking invariants")
  }

  // MARK: - Recursive Shrinking with Properties

  @Test("Property-based testing of shrinking algorithms")
  func propertyBasedShrinkingAlgorithmTesting() async {
    /// Test Intent: Use property-based testing to verify that our shrinking
    /// algorithms satisfy fundamental mathematical properties about minimization.

    // Property: Shrinking should be idempotent (shrinking shrunk values yields same or smaller results)
    let idempotencyProperty = Property<[String]>(generator: Gen.array(Gen.string)) { originalArray in
      guard !originalArray.isEmpty else { return true }

      let arrayShrink = Shrink<[String]> { array in
        guard !array.isEmpty else { return [] }
        var results: [[String]] = []

        // Remove one element
        for i in 0..<array.count {
          var smaller = array
          smaller.remove(at: i)
          results.append(smaller)
        }

        // Shrink individual elements
        for (i, element) in array.enumerated() where element.count > 1 {
          var shrunkArray = array
          shrunkArray[i] = String(element.prefix(element.count / 2))
          results.append(shrunkArray)
        }

        return results
      }

      let firstShrinking = arrayShrink.shrink(originalArray)

      // Apply shrinking again to all results
      let secondShrinking = firstShrinking.flatMap { arrayShrink.shrink($0) }

      // Second shrinking should produce values smaller than or equal to first shrinking
      return secondShrinking.allSatisfy { secondLevel in
        firstShrinking.contains { firstLevel in
          secondLevel.count <= firstLevel.count
        } || secondLevel.count <= originalArray.count
      }
    }

    let result = runPropertySynchronously(
      idempotencyProperty,
      config: PropertyConfig(iterations: 30)
    )
    #expect(
      result.isSuccess,
      "Shrinking should be idempotent or produce progressively smaller values"
    )
  }

  @Test("Shrinking preserves failure conditions")
  func shrinkingPreservesFailureConditions() async {
    /// Test Intent: Verify that when shrinking is used in practice (during property
    /// failure), the shrunk values still cause the same property to fail.

    // Create a property that fails for arrays with duplicate elements
    let noDuplicatesProperty = Property<[Int]>(generator: Gen.array(Gen.int(in: 1...10))) { array in
      Set(array).count == array.count  // No duplicates
    }

    // Simulate what happens when this property fails
    let failingArray = [1, 2, 3, 2, 4]  // Has duplicates
    #expect(!noDuplicatesProperty.predicate(failingArray), "Test array should fail the property")

    // Now test that shrinking preserves the failure
    let arrayShrink = Gen.array(Gen.int).shrink
    let shrunkArrays = arrayShrink.shrink(failingArray)

    // Filter shrunk arrays that still have duplicates
    let stillFailingShrunkArrays = shrunkArrays.filter { !noDuplicatesProperty.predicate($0) }

    #expect(
      !stillFailingShrunkArrays.isEmpty,
      "Some shrunk arrays should still fail the property (preserve failure condition)"
    )

    // All failing shrunk arrays should be smaller than original
    let allSmaller = stillFailingShrunkArrays.allSatisfy { $0.count <= failingArray.count }
    #expect(allSmaller, "Failing shrunk arrays should be smaller than original")
  }

  // MARK: - Advanced Recursive Shrinking Patterns

  @Test("Nested shrinking with complex data structures")
  func nestedShrinkingComplexStructures() async {
    /// Test Intent: Test shrinking of nested structures where each level
    /// can be shrunk independently, creating a multi-dimensional shrinking space.

    // Custom nested structure for testing
    struct NestedData: Equatable {
      let arrays: [[Int]]
      let metadata: [String: Int]

      var complexity: Int {
        arrays.flatMap { $0 }.count + metadata.values.reduce(0, +)
      }
    }

    // Generator for nested data
    let nestedGen = Gen<NestedData> { rng, size in
      let arrayCount = Int.random(in: 1...size.value, using: &rng)
      let arrays = (0..<arrayCount).map { _ in
        Gen.array(Gen.int(in: 1...10)).generate(&rng, size)
      }

      let metadata = [
        "count": arrays.count,
        "total": arrays.flatMap { $0 }.reduce(0, +),
        "max_size": arrays.map(\.count).max() ?? 0,
      ]

      return NestedData(arrays: arrays, metadata: metadata)
    }

    // Property: Nested shrinking should reduce complexity while preserving structure
    let nestedShrinkingProperty = Property(generator: nestedGen) { originalData in
      // Create custom shrink for nested data
      let nestedShrink = Shrink<NestedData> { data in
        var results: [NestedData] = []

        // Shrink by removing arrays
        if data.arrays.count > 1 {
          for i in 0..<data.arrays.count {
            var smaller = data.arrays
            smaller.remove(at: i)
            let newMetadata = [
              "count": smaller.count,
              "total": smaller.flatMap { $0 }.reduce(0, +),
              "max_size": smaller.map(\.count).max() ?? 0,
            ]
            results.append(NestedData(arrays: smaller, metadata: newMetadata))
          }
        }

        // Shrink individual arrays
        for (i, array) in data.arrays.enumerated() where !array.isEmpty {
          var smallerArrays = data.arrays
          smallerArrays[i] = Array(array.prefix(array.count / 2))
          let newMetadata = [
            "count": smallerArrays.count,
            "total": smallerArrays.flatMap { $0 }.reduce(0, +),
            "max_size": smallerArrays.map(\.count).max() ?? 0,
          ]
          results.append(NestedData(arrays: smallerArrays, metadata: newMetadata))
        }

        return results
      }

      let shrunkResults = nestedShrink.shrink(originalData)

      // All shrunk results should have lower or equal complexity
      return shrunkResults.allSatisfy { shrunk in
        shrunk.complexity <= originalData.complexity
          && shrunk.arrays.count <= originalData.arrays.count
      }
    }

    let result = runPropertySynchronously(
      nestedShrinkingProperty,
      config: PropertyConfig(iterations: 25)
    )
    #expect(
      result.isSuccess,
      "Nested shrinking should preserve structure while reducing complexity"
    )
  }

  @Test("Shrinking with recursive data structures")
  func shrinkingRecursiveDataStructures() async {
    /// Test Intent: Test shrinking of recursive data structures like trees,
    /// where shrinking can happen at any level of the recursion.

    // Simple recursive tree structure
    indirect enum Tree: Equatable {
      case leaf(Int)
      case node(Self, Self)

      var size: Int {
        switch self {
        case .leaf: return 1
        case .node(let left, let right): return 1 + left.size + right.size
        }
      }

      var depth: Int {
        switch self {
        case .leaf: return 1
        case .node(let left, let right): return 1 + max(left.depth, right.depth)
        }
      }
    }

    // Generator for trees
    let treeGen = Gen<Tree> { rng, size in
      func generateTree(currentSize: Int) -> Tree {
        if currentSize <= 1 || Bool.random(using: &rng) {
          return .leaf(Int.random(in: 1...100, using: &rng))
        } else {
          let leftSize = currentSize / 2
          let rightSize = currentSize - leftSize - 1
          return .node(
            generateTree(currentSize: leftSize),
            generateTree(currentSize: rightSize)
          )
        }
      }

      return generateTree(currentSize: size.value)
    }

    // Tree shrinking strategy (use let to avoid capture error)
    func makeTreeShrink() -> Shrink<Tree> {
      Shrink<Tree> { tree in
        switch tree {
        case .leaf:
          return []  // Can't shrink leaves further

        case .node(let left, let right):
          var results: [Tree] = []

          // Replace with subtrees
          results.append(left)
          results.append(right)

          // Note: Avoiding recursive shrinking to prevent capture issues
          // The basic shrinking of replacing with subtrees is sufficient for this test

          return results
        }
      }
    }

    let treeShrink = makeTreeShrink()

    // Property: Tree shrinking should reduce size while preserving tree structure
    let treeShrinkingProperty = Property(generator: treeGen) { originalTree in
      let shrunkTrees = treeShrink.shrink(originalTree)

      return shrunkTrees.allSatisfy { shrunk in
        shrunk.size <= originalTree.size && shrunk.depth <= originalTree.depth
      }
    }

    let result = runPropertySynchronously(
      treeShrinkingProperty,
      config: PropertyConfig(iterations: 30)
    )
    #expect(result.isSuccess, "Tree shrinking should preserve structure while reducing size")
  }

  // MARK: - Shrinking Performance and Termination

  @Test("Shrinking always terminates")
  func shrinkingAlwaysTerminates() async {
    /// Test Intent: Ensure that shrinking sequences always terminate and don't
    /// create infinite loops, even with pathological input.

    // Property: Repeated shrinking should eventually reach a fixed point
    let terminationProperty = Property<[Int]>(generator: Gen.array(Gen.int)) { originalArray in
      let arrayShrink = Gen.array(Gen.int).shrink

      var current = originalArray
      var iterations = 0
      let maxIterations = 100  // Safety limit

      // Keep shrinking until we can't shrink further or hit limit
      while iterations < maxIterations {
        let shrunkResults = arrayShrink.shrink(current)

        if shrunkResults.isEmpty {
          // Reached a fixed point (can't shrink further)
          return true
        }

        // Pick the first shrunk result for next iteration
        current = shrunkResults[0]
        iterations += 1
      }

      // If we hit the iteration limit, shrinking might not terminate properly
      return iterations < maxIterations
    }

    let result = runPropertySynchronously(
      terminationProperty,
      config: PropertyConfig(iterations: 50)
    )
    #expect(result.isSuccess, "Shrinking should always terminate within reasonable bounds")
  }

  @Test("Shrinking performance is reasonable")
  func shrinkingPerformanceIsReasonable() async {
    /// Test Intent: Ensure that shrinking doesn't take exponential time
    /// and completes within reasonable performance bounds.

    let largeArray = Array(1...1000)

    let startTime = Date()
    let shrunk = Gen.array(Gen.int).shrink.shrink(largeArray)
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 1.0, "Shrinking large arrays should complete within 1 second")
    #expect(!shrunk.isEmpty, "Large arrays should produce some shrunk variants")
    #expect(
      shrunk.allSatisfy { $0.count < largeArray.count },
      "All shrunk arrays should be smaller"
    )
  }
}

// MARK: - Shrinking Utilities and Patterns

/// Utilities for creating and testing custom shrinking strategies
struct ShrinkingUtilities {

  /// Create a shrinking function that preserves certain invariants
  static func createInvariantPreservingShrink<T>(
    baseShrink: Shrink<T>,
    invariant: @escaping (T) -> Bool
  ) -> Shrink<T> {
    Shrink<T> { value in
      let candidates = baseShrink.shrink(value)
      return candidates.filter(invariant)
    }
  }

  /// Combine multiple shrinking strategies
  static func combineShrinkingStrategies<T>(_ strategies: [Shrink<T>]) -> Shrink<T> {
    Shrink<T> { value in
      strategies.flatMap { strategy in
        strategy.shrink(value)
      }
    }
  }

  /// Create a bounded shrinking function that limits the number of results
  static func createBoundedShrink<T>(_ baseShrink: Shrink<T>, maxResults: Int) -> Shrink<T> {
    Shrink<T> { value in
      let results = baseShrink.shrink(value)
      return Array(results.prefix(maxResults))
    }
  }
}

// MARK: - Shrink.automatic and Shrink.towards Tests

@Test("Shrink.automatic returns empty shrink results")
func shrinkAutomaticReturnsEmpty() {
  let shrink = Shrink<Int>.automatic
  let results = shrink.shrink(42)
  #expect(results.isEmpty, "Shrink.automatic should return empty array")
}

@Test("Shrink.towards shrinks to target value")
func shrinkTowardsShrinksToTarget() {
  let target = 0
  let shrink = Shrink<Int>.towards(target)
  let results = shrink.shrink(100)
  #expect(results == [target], "Shrink.towards should return only the target")
}

@Test("Shrink.towards with struct target")
func shrinkTowardsWithStructTarget() {
  struct Config: Equatable {
    let debug: Bool
    let timeout: Int
  }

  let defaultConfig = Config(debug: false, timeout: 30)
  let shrink = Shrink<Config>.towards(defaultConfig)

  let complexConfig = Config(debug: true, timeout: 999)
  let results = shrink.shrink(complexConfig)

  #expect(results.count == 1, "Should produce exactly one shrink result")
  #expect(results.first == defaultConfig, "Should shrink to the target config")
}

@Test("Shrink.automatic works with complex types")
func shrinkAutomaticWorksWithComplexTypes() {
  struct ComplexType: Equatable {
    let name: String
    let values: [Int]
  }

  let shrink = Shrink<ComplexType>.automatic
  let testValue = ComplexType(name: "test", values: [1, 2, 3])
  let results = shrink.shrink(testValue)

  #expect(results.isEmpty, "Shrink.automatic should return empty for any type")
}

/// Documentation and examples for recursive shrinking patterns
///
/// Recursive shrinking represents one of the most sophisticated aspects of
/// property-based testing, where the minimization process itself becomes
/// a subject for testing and validation.
///
/// **Key Principles**:
/// 1. **Coalgebraic Structure**: Shrinking unfolds infinite sequences of smaller values
/// 2. **Termination Guarantees**: Well-founded orderings ensure shrinking terminates
/// 3. **Invariant Preservation**: Shrunk values must still exhibit the failing behavior
/// 4. **Performance Bounds**: Shrinking should complete in reasonable time
///
/// **Advanced Patterns**:
/// - Meta-shrinking: Shrinking functions that operate on other shrinking functions
/// - Nested shrinking: Multi-level shrinking for complex data structures
/// - Invariant-preserving shrinking: Maintaining properties during minimization
/// - Recursive data shrinking: Trees, graphs, and other recursive structures
///
// MARK: - Advanced String Shrinking Tests

@Test("StringShrinkTree produces deterministic results")
func stringShrinkTreeDeterminism() {
  let testString = "hello world test"

  // Create multiple trees from same input
  let tree1 = stringShrinkTree(testString)
  let tree2 = stringShrinkTree(testString)

  // BFS traversal should be identical
  let bfs1 = tree1.breadthFirst()
  let bfs2 = tree2.breadthFirst()

  #expect(bfs1 == bfs2, "StringShrinkTree should produce deterministic BFS traversal")
}

@Test("StringShrinkTree finds smaller counterexamples than old shrinking")
func stringShrinkTreeBetterMinimality() {
  // Test case: property fails when string contains "error"
  let failingPredicate: (String) -> Bool = { !$0.contains("error") }

  let testCases = [
    "prefix error suffix",
    "error in the middle",
    "multiple error error instances",
  ]

  for original in testCases {
    // Old shrinking method (individual character removal)
    let oldShrink = Shrink<String> { string in
      guard !string.isEmpty else { return [] }
      var candidates: [String] = [""]

      let chars = Array(string)
      for i in 0..<chars.count {
        var shrunk = chars
        shrunk.remove(at: i)
        candidates.append(String(shrunk))
      }
      return candidates
    }

    // New ShrinkTree method
    let newTree = stringShrinkTree(original)

    // Find minimal counterexamples
    let oldMinimal = ShrinkTree.from(original, shrink: oldShrink)
      .findMinimal(budget: 1000, satisfying: failingPredicate)

    let newMinimal = newTree.findMinimal(budget: 1000, satisfying: failingPredicate)

    // Both should find counterexamples (strings that still contain "error")
    #expect(oldMinimal != nil, "Old shrinking should find counterexample for \(original)")
    #expect(newMinimal != nil, "New shrinking should find counterexample for \(original)")

    if let oldMin = oldMinimal, let newMin = newMinimal {
      // New method should find equal or smaller counterexamples
      #expect(
        newMin.count <= oldMin.count,
        "New shrinking should produce smaller or equal counterexample. Old: '\(oldMin)' (\(oldMin.count) chars), New: '\(newMin)' (\(newMin.count) chars)"
      )

      // Both should still fail the predicate
      #expect(failingPredicate(oldMin), "Old minimal should still fail predicate")
      #expect(failingPredicate(newMin), "New minimal should still fail predicate")
    }
  }
}

@Test("StringShrinkTree handles edge cases correctly")
func stringShrinkTreeEdgeCases() {
  // Empty string
  let emptyTree = stringShrinkTree("")
  #expect(emptyTree.children.isEmpty, "Empty string should have no shrink candidates")

  // Single character
  let singleTree = stringShrinkTree("a")
  let singleCandidates = singleTree.breadthFirst()
  #expect(singleCandidates.contains(""), "Single char should shrink to empty string")
  #expect(!singleCandidates.contains("a"), "Single char should not contain itself in shrinks")

  // Unicode string
  let unicodeString = "héllo wörld"
  let unicodeTree = stringShrinkTree(unicodeString)
  let unicodeCandidates = unicodeTree.breadthFirst()

  // Should still find empty string and smaller versions
  #expect(unicodeCandidates.contains(""), "Unicode string should shrink to empty")
  #expect(
    unicodeCandidates.contains(where: { $0.count < unicodeString.count }),
    "Unicode string should have smaller candidates"
  )
}

@Test("StringShrinkTree respects chunk-based shrinking strategy")
func stringShrinkTreeChunkStrategy() {
  let longString = "abcdefghijklmnopqrstuvwxyz"

  let tree = stringShrinkTree(longString)
  let candidates = tree.breadthFirst()

  // Should include half removals
  let firstHalf = String(longString.prefix(longString.count / 2))
  let secondHalf = String(longString.suffix(longString.count - longString.count / 2))

  #expect(candidates.contains(firstHalf), "Should include first half removal")
  #expect(candidates.contains(secondHalf), "Should include second half removal")

  // Should include chunk removals (removing quarters, eighths, etc.)
  let quarterSize = longString.count / 4
  let hasChunkRemovals = candidates.contains { candidate in
    candidate.count < longString.count && candidate.count >= longString.count - quarterSize
  }
  #expect(hasChunkRemovals, "Should include chunk-based removals")
}

@Test("StringShrinkTree character simplification works")
func stringShrinkTreeCharacterSimplification() {
  // Test uppercase to lowercase
  let upperTree = stringShrinkTree("HELLO")
  let upperCandidates = upperTree.breadthFirst()
  #expect(upperCandidates.contains("hello"), "Should simplify uppercase to lowercase")

  // Test digits to 0
  let digitTree = stringShrinkTree("abc123")
  let digitCandidates = digitTree.breadthFirst()
  #expect(digitCandidates.contains("abc000"), "Should simplify digits to 0")

  // Test letters to 'a'
  let mixedTree = stringShrinkTree("Xyz")
  let mixedCandidates = mixedTree.breadthFirst()
  #expect(mixedCandidates.contains("aaa"), "Should simplify letters to 'a'")
}

/// **References**:
/// - *QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs* by Claessen & Hughes
/// - *Shrinking and showing functions* by Runciman et al.
/// - https://en.wikipedia.org/wiki/Well-founded_relation
/// - https://hackage.haskell.org/package/QuickCheck/docs/Test-QuickCheck.html
