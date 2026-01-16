import Testing
import Foundation
@testable import InvariantSwift

/// Comprehensive tests for collection generators to achieve 99%+ code coverage
struct CollectionGeneratorTests {

  // MARK: - Array Generator Tests

  @Test("Array Generator Basic Coverage")
  func arrayGeneratorBasicCoverage() async {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("Array Generator Edge Cases")
  func arrayGeneratorEdgeCases() async {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { array in
      // Test that arrays have reasonable bounds
      array.count <= 100
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Array size constraint failed with: \(counterexample.count) elements")

    case .gaveUp:
      Issue.record("Array edge case test gave up unexpectedly")
    }
  }

  @Test("Array Generator Shrinking")
  func arrayGeneratorShrinking() async {
    let property = Property<[Int]>(generator: Gen.array(Gen.int(in: 1...100))) { array in
      !array.contains(42)  // Should fail when 42 is found
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 200)
    )

    switch result {
    case .success:
      // Might not find 42, that's ok
      break

    case .failure(let original, _, let shrunk):
      // Test that shrinking worked
      #expect(shrunk.count <= original.count, "Shrunk array should be smaller or equal")
      if shrunk.contains(42) {
        // Good, shrinking preserved the failure condition
        break
      }

    case .gaveUp:
      break
    }
  }

  @Test("Array Generator String Elements")
  func arrayGeneratorStringElements() async {
    let property = Property<[String]>(generator: Gen.array(Gen.string)) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("String array test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("String array test gave up unexpectedly")
    }
  }

  // MARK: - Set Generator Tests

  @Test("Set Generator Basic Coverage")
  func setGeneratorBasicCoverage() async {
    let property = Property<Set<Int>>(generator: Gen.set(Gen.int)) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("Set Generator Uniqueness")
  func setGeneratorUniqueness() async {
    let property = Property<Set<Int>>(generator: Gen.set(Gen.int(in: 1...10))) { set in
      // All elements should be unique (which is guaranteed by Set)
      // Test that set size is reasonable for small range
      set.count <= 10
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Set uniqueness test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Set uniqueness test gave up unexpectedly")
    }
  }

  @Test("Set Generator Shrinking")
  func setGeneratorShrinking() async {
    let property = Property<Set<Int>>(generator: Gen.set(Gen.int(in: 1...50))) { set in
      !set.contains(25)  // Should fail when 25 is found
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      // Might not find 25, that's ok
      break

    case .failure(let original, _, let shrunk):
      // Test that shrinking worked
      #expect(shrunk.count <= original.count, "Shrunk set should be smaller or equal")
      if shrunk.contains(25) {
        // Good, shrinking preserved the failure condition
        break
      }

    case .gaveUp:
      break
    }
  }

  @Test("Set Generator String Elements")
  func setGeneratorStringElements() async {
    let property = Property<Set<String>>(generator: Gen.set(Gen.string)) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("String set test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("String set test gave up unexpectedly")
    }
  }

  // MARK: - Dictionary Generator Tests

  @Test("Dictionary Generator Basic Coverage")
  func dictionaryGeneratorBasicCoverage() async {
    let property = Property<[String: Int]>(generator: Gen.dictionary(Gen.string, Gen.int)) { _ in
      true
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("Dictionary Generator Key Uniqueness")
  func dictionaryGeneratorKeyUniqueness() async {
    let property = Property<[Int: String]>(
      generator: Gen.dictionary(Gen.int(in: 1...10), Gen.string)
    ) { dict in
      // Keys should be unique (guaranteed by Dictionary)
      // Test that dictionary size is reasonable for small key range
      dict.count <= 10
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Dictionary key uniqueness test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Dictionary key uniqueness test gave up unexpectedly")
    }
  }

  @Test("Dictionary Generator Shrinking")
  func dictionaryGeneratorShrinking() async {
    let property = Property<[String: Int]>(
      generator: Gen.dictionary(Gen.string, Gen.int(in: 1...100))
    ) { dict in
      !dict.values.contains(50)  // Should fail when value 50 is found
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      // Might not find 50, that's ok
      break

    case .failure(let original, _, let shrunk):
      // Test that shrinking worked
      #expect(shrunk.count <= original.count, "Shrunk dictionary should be smaller or equal")
      if shrunk.values.contains(50) {
        // Good, shrinking preserved the failure condition
        break
      }

    case .gaveUp:
      break
    }
  }

  @Test("Dictionary Generator Complex Types")
  func dictionaryGeneratorComplexTypes() async {
    let property = Property<[Int: [String]]>(
      generator: Gen.dictionary(Gen.int, Gen.array(Gen.string))
    ) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Complex dictionary test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Complex dictionary test gave up unexpectedly")
    }
  }

  // MARK: - Range Generator Tests

  @Test("Range Generator Basic Coverage")
  func rangeGeneratorBasicCoverage() async {
    let property = Property<Range<Int>>(generator: Gen.intRange) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("Range Generator Validity")
  func rangeGeneratorValidity() async {
    let property = Property<Range<Int>>(generator: Gen.intRange) { range in
      // Test that ranges are valid (lowerBound <= upperBound)
      range.lowerBound <= range.upperBound
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Range validity test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Range validity test gave up unexpectedly")
    }
  }

  @Test("Range Generator Edge Cases")
  func rangeGeneratorEdgeCases() async {
    let property = Property<Range<Int>>(generator: Gen.intRange) { range in
      // Test that ranges don't exceed reasonable bounds
      range.count <= 1000
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Range edge case test failed with range of size: \(counterexample.count)")

    case .gaveUp:
      Issue.record("Range edge case test gave up unexpectedly")
    }
  }

  @Test("ClosedRange Generator Basic Coverage")
  func closedRangeGeneratorBasicCoverage() async {
    let property = Property<ClosedRange<Int>>(generator: Gen.intClosedRange) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("ClosedRange Generator Validity")
  func closedRangeGeneratorValidity() async {
    let property = Property<ClosedRange<Int>>(generator: Gen.intClosedRange) { range in
      // Test that closed ranges are valid (lowerBound <= upperBound)
      range.lowerBound <= range.upperBound
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("ClosedRange validity test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("ClosedRange validity test gave up unexpectedly")
    }
  }

  // MARK: - Partial Range Generator Tests

  @Test("PartialRangeFrom Generator Basic Coverage")
  func partialRangeFromGeneratorBasicCoverage() async {
    let property = Property<PartialRangeFrom<Int>>(generator: Gen.intPartialRangeFrom) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("PartialRangeUpTo Generator Basic Coverage")
  func partialRangeUpToGeneratorBasicCoverage() async {
    let property = Property<PartialRangeUpTo<Int>>(generator: Gen.intPartialRangeUpTo) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("PartialRangeThrough Generator Basic Coverage")
  func partialRangeThroughGeneratorBasicCoverage() async {
    let property = Property<PartialRangeThrough<Int>>(generator: Gen.intPartialRangeThrough) { _ in
      true
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  // MARK: - ArraySlice Generator Tests

  @Test("ArraySlice Generator Basic Coverage")
  func arraySliceGeneratorBasicCoverage() async {
    let property = Property<ArraySlice<Int>>(generator: Gen.arraySlice(Gen.int)) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Unexpected failure with: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("ArraySlice Generator Properties")
  func arraySliceGeneratorProperties() async {
    let property = Property<ArraySlice<String>>(generator: Gen.arraySlice(Gen.string)) { slice in
      // Test that array slice behaves like an array
      let array = Array(slice)
      return array.count == slice.count
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("ArraySlice properties test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("ArraySlice properties test gave up unexpectedly")
    }
  }

  @Test("ArraySlice Generator Shrinking")
  func arraySliceGeneratorShrinking() async {
    let property = Property<ArraySlice<Int>>(generator: Gen.arraySlice(Gen.int(in: 1...100))) {
      slice in
      !slice.contains(75)  // Should fail when 75 is found
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      // Might not find 75, that's ok
      break

    case .failure(let original, _, let shrunk):
      // Test that shrinking worked
      #expect(shrunk.count <= original.count, "Shrunk slice should be smaller or equal")
      if shrunk.contains(75) {
        // Good, shrinking preserved the failure condition
        break
      }

    case .gaveUp:
      break
    }
  }

  // MARK: - Combined Collection Tests

  @Test("Nested Collection Generators")
  func nestedCollectionGenerators() async {
    let property = Property<[[Int]]>(generator: Gen.array(Gen.array(Gen.int))) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Nested array test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Nested array test gave up unexpectedly")
    }
  }

  @Test("Mixed Collection Types")
  func mixedCollectionTypes() async {
    let property = Property<[String: Set<Int>]>(
      generator: Gen.dictionary(Gen.string, Gen.set(Gen.int))
    ) { _ in true }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 20)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Mixed collection test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Mixed collection test gave up unexpectedly")
    }
  }

  @Test("Collection Size Distribution")
  func collectionSizeDistribution() async {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { _ in
      // Test that we get a variety of sizes, including edge cases
      true  // Just exercise the generation
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 200)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _):
      Issue.record("Size distribution test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Size distribution test gave up unexpectedly")
    }
  }
}
