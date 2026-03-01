import Testing
import Foundation
@testable import InvariantSwift
import InvariantSwiftCore

/// Tests for SHRINK-COLL-001: Collection shrinking v2
///
/// Verifies:
/// - Chunk removal strategy (delta-debugging)
/// - Deterministic candidate ordering
/// - Hash-based key sorting for dictionaries
@Suite(.serialized)
struct CollectionShrinkingV2Tests {

  @Test("Array shrinking produces chunk deletions before element shrinks")
  func arrayChunkDeletions() {
    let gen = Gen<[Int]>.array(Gen<Int>.int(in: 0...100))
    let array = [1, 2, 3, 4, 5, 6, 7, 8]

    let shrinks = gen.shrink.shrink(array)

    guard !shrinks.isEmpty else {
      Issue.record("Expected shrink candidates")
      return
    }

    #expect(shrinks.contains([]), "Empty array should be first chunk removal candidate")

    let hasHalfDeletion = shrinks.contains([5, 6, 7, 8]) || shrinks.contains([1, 2, 3, 4])
    #expect(hasHalfDeletion, "Should include half-array deletion")

    let hasQuarterDeletion = shrinks.contains(where: { $0.count == 6 })
    #expect(hasQuarterDeletion, "Should include quarter deletions")
  }

  @Test("Array shrinking is deterministic")
  func arrayShrinkingDeterminism() {
    let gen = Gen<[Int]>.array(Gen<Int>.int(in: 0...10))
    let array = [5, 3, 8, 1, 9]

    let shrinks1 = gen.shrink.shrink(array)
    let shrinks2 = gen.shrink.shrink(array)
    let shrinks3 = gen.shrink.shrink(array)

    #expect(shrinks1.count == shrinks2.count, "Same input should produce same number of shrinks")
    #expect(shrinks2.count == shrinks3.count, "Deterministic shrink count")

    for (idx, (s1, s2)) in zip(shrinks1, shrinks2).enumerated() {
      #expect(s1 == s2, "Shrink candidate \(idx) should be identical across runs")
    }
  }

  @Test("Dictionary shrinking uses hash-based ordering")
  func dictionaryShrinkingDeterminism() {
    let gen = Gen<[String: Int]>.dictionary(Gen<String>.string, Gen<Int>.int(in: 0...100))
    let dict = ["apple": 1, "banana": 2, "cherry": 3, "date": 4]

    let shrinks1 = gen.shrink.shrink(dict)
    let shrinks2 = gen.shrink.shrink(dict)
    let shrinks3 = gen.shrink.shrink(dict)

    #expect(shrinks1.count == shrinks2.count, "Same dict should produce same number of shrinks")
    #expect(shrinks2.count == shrinks3.count, "Deterministic shrink count")

    for (idx, (s1, s2)) in zip(shrinks1, shrinks2).enumerated() {
      #expect(s1 == s2, "Shrink candidate \(idx) should be identical across runs")
    }
  }

  @Test("Dictionary shrinking produces chunk deletions")
  func dictionaryChunkDeletions() {
    let gen = Gen<[String: Int]>.dictionary(Gen<String>.string, Gen<Int>.int(in: 0...100))
    let dict = ["a": 1, "b": 2, "c": 3, "d": 4, "e": 5, "f": 6, "g": 7, "h": 8]

    let shrinks = gen.shrink.shrink(dict)

    guard !shrinks.isEmpty else {
      Issue.record("Expected shrink candidates")
      return
    }

    #expect(shrinks.contains([:]), "Empty dictionary should be first chunk removal candidate")

    let hasHalfDeletion = shrinks.contains(where: { $0.count == 4 })
    #expect(hasHalfDeletion, "Should include half-dictionary deletion (4 pairs)")
  }

  @Test("Array shrinking minimality: chunk removal finds smaller arrays faster")
  func arrayShrinkingMinimality() {
    let gen = Gen<[Int]>.array(Gen<Int>.int)
    let largeArray = Array(0..<20)

    let shrinks = gen.shrink.shrink(largeArray)

    guard !shrinks.isEmpty else {
      Issue.record("Expected shrink candidates")
      return
    }

    let emptyCandidateIndex = shrinks.firstIndex(of: [])
    #expect(emptyCandidateIndex == 0, "Empty array should be the first candidate")

    let halfSizeCandidateIndex = shrinks.firstIndex(where: { $0.count == 10 })
    let singleElementDeletionIndex = shrinks.firstIndex(where: { $0.count == 19 })

    if let halfIdx = halfSizeCandidateIndex, let singleIdx = singleElementDeletionIndex {
      #expect(halfIdx < singleIdx, "Chunk deletions should come before single-element deletions")
    }
  }

  @Test("Shrink.removeElements produces expected sequence")
  func removeElementsSequence() {
    let array = [1, 2, 3, 4, 5, 6, 7, 8]
    let shrinks = Shrink<[Int]>.removeElements(from: array)

    #expect(shrinks.contains([]), "Should include empty array")

    #expect(shrinks.contains([5, 6, 7, 8]), "Should remove first half")
    #expect(shrinks.contains([1, 2, 3, 4]), "Should remove second half")

    #expect(shrinks.contains([3, 4, 5, 6, 7, 8]), "Should remove first quarter")
    #expect(shrinks.contains([1, 2, 5, 6, 7, 8]), "Should remove second quarter")

    let singleDeletions = shrinks.filter { $0.count == 7 }
    #expect(singleDeletions.count == 8, "Should have 8 single-element deletions")
  }

  @Test("Shrink.shrinkElements preserves array structure")
  func shrinkElementsPreservesStructure() {
    let shrinker: (Int) -> [Int] = { n in
      n > 0 ? [0, n / 2] : []
    }

    let array = [10, 20, 30]
    let shrinks = Shrink<[Int]>.shrinkElements(in: array, using: shrinker)

    #expect(shrinks.contains([0, 20, 30]), "Should shrink first element to 0")
    #expect(shrinks.contains([5, 20, 30]), "Should shrink first element to half")
    #expect(shrinks.contains([10, 0, 30]), "Should shrink second element to 0")
    #expect(shrinks.contains([10, 20, 0]), "Should shrink third element to 0")

    #expect(shrinks.allSatisfy { $0.count == 3 }, "All shrinks should preserve array length")
  }

  @Test("Dictionary shrinking candidate ordering is stable")
  func dictionaryCandidateOrdering() {
    let gen = Gen<[Int: String]>.dictionary(Gen<Int>.int(in: 0...10), Gen<String>.string)
    let dict = [1: "a", 2: "b", 3: "c", 4: "d"]

    let shrinks1 = gen.shrink.shrink(dict)
    let shrinks2 = gen.shrink.shrink(dict)

    #expect(shrinks1.count == shrinks2.count, "Stable candidate count")

    for (s1, s2) in zip(shrinks1, shrinks2) {
      #expect(s1 == s2, "Candidates should be in identical order")
    }
  }

  @Test("Empty collections shrink to empty")
  func emptyCollectionsShrinking() {
    let arrayGen = Gen<[Int]>.array(Gen<Int>.int)
    let arrayShrinks = arrayGen.shrink.shrink([])
    #expect(arrayShrinks.isEmpty, "Empty array has no shrinks")

    let dictGen = Gen<[String: Int]>.dictionary(Gen<String>.string, Gen<Int>.int)
    let dictShrinks = dictGen.shrink.shrink([:])
    #expect(dictShrinks.isEmpty, "Empty dictionary has no shrinks")
  }

  @Test("Single-element collections shrink correctly")
  func singleElementShrinking() {
    let arrayGen = Gen<[Int]>.array(Gen<Int>.int(in: 0...100))
    let arrayShrinks = arrayGen.shrink.shrink([42])

    #expect(arrayShrinks.contains([]), "Single element array should shrink to empty")

    let dictGen = Gen<[String: Int]>.dictionary(Gen<String>.string, Gen<Int>.int(in: 0...100))
    let dictShrinks = dictGen.shrink.shrink(["key": 42])

    #expect(dictShrinks.contains([:]), "Single pair dictionary should shrink to empty")
  }
}
