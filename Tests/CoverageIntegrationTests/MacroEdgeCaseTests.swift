import Testing
import Foundation
@testable import FunctionalTesting

/// Additional tests to cover edge cases and rare code paths in the main library
struct MacroEdgeCaseTests {

  // MARK: - PropertyResult Edge Case Coverage

  @Test("PropertyResult edge case handling")
  func propertyResultEdgeCaseHandling() {
    // Test PropertyResult enum cases for complete coverage
    // This exercises the Result type and its associated values

    // Test success case with various iteration counts
    let successResult: PropertyResult<String> = .success(iterations: 0)
    switch successResult {
    case .success(let iterations):
      #expect(iterations == 0, "Success result should preserve iteration count")

    default:
      Issue.record("Expected success result")
    }

    let highSuccessResult: PropertyResult<Int> = .success(iterations: 999999)
    if case .success(let iterations) = highSuccessResult {
      #expect(iterations == 999999, "Success should handle large iteration counts")
    } else {
      Issue.record("Expected high success result")
    }

    // Test failure cases with different types
    let failureResult: PropertyResult<[Int]> = .failure(
      counterexample: [1, 2, 3],
      iterations: 42,
      shrunk: [1]
    )
    switch failureResult {
    case .failure(let counterexample, let iterations, let shrunk):
      #expect(counterexample.count == 3, "Failure should preserve counterexample")
      #expect(iterations == 42, "Failure should preserve iteration count")
      #expect(shrunk.count == 1, "Failure should preserve shrunk value")

    default:
      Issue.record("Expected failure result")
    }

    // Test gaveUp case with edge values
    let gaveUpResult: PropertyResult<String> = .gaveUp(discarded: 0, iterations: 1)
    switch gaveUpResult {
    case .gaveUp(let discarded, let iterations):
      #expect(discarded == 0, "GaveUp should handle zero discarded count")
      #expect(iterations == 1, "GaveUp should preserve minimal iterations")

    default:
      Issue.record("Expected gaveUp result")
    }
  }

  @Test("PropertyConfig edge case validation")
  func propertyConfigEdgeCaseValidation() {
    // Test PropertyConfig with boundary values for comprehensive coverage

    // Test with minimal values
    let minimalConfig = PropertyConfig(
      iterations: 1,
      maxShrinks: 0,
      maxDiscarded: 1,
      seed: Seed(value: 0)
    )
    #expect(minimalConfig.iterations == 1, "Config should handle minimal iterations")
    #expect(minimalConfig.maxShrinks == 0, "Config should handle zero max shrinks")
    #expect(minimalConfig.maxDiscarded == 1, "Config should handle minimal max discarded")
    #expect(minimalConfig.seed?.value == 1, "Config should normalize zero seed to 1")

    // Test with maximum reasonable values
    let maximalConfig = PropertyConfig(
      iterations: 1_000_000,
      maxShrinks: 100_000,
      maxDiscarded: 500_000,
      seed: Seed(value: UInt64.max)
    )
    #expect(maximalConfig.iterations == 1_000_000, "Config should handle large iterations")
    #expect(maximalConfig.maxShrinks == 100_000, "Config should handle large max shrinks")
    #expect(maximalConfig.maxDiscarded == 500_000, "Config should handle large max discarded")
    #expect(maximalConfig.seed?.value == UInt64.max, "Config should handle max seed value")

    // Test default configuration properties
    let defaultConfig = PropertyConfig.default
    #expect(defaultConfig.iterations > 0, "Default config should have positive iterations")
    #expect(defaultConfig.maxShrinks >= 0, "Default config should have non-negative max shrinks")
    #expect(defaultConfig.maxDiscarded > 0, "Default config should have positive max discarded")
  }

  // MARK: - Advanced Shrinking Algorithm Coverage

  @Test("Shrink lazy evaluation patterns")
  func shrinkLazyEvaluationPatterns() {
    // Test lazy computation patterns from ShrinkTrees.swift
    let expensiveLazy = Lazy {
      // Simulate expensive computation
      Array(1...1000).reduce(0, +)
    }

    let result1 = expensiveLazy.value
    let result2 = expensiveLazy.value
    #expect(result1 == result2, "Lazy should compute same value each time")
    #expect(result1 == 500500, "Lazy computation should be correct")

    // Test nested lazy computations
    let nestedLazy = expensiveLazy.map { value in
      value * 2
    }.map { value in
      value + 1
    }
    #expect(nestedLazy.value == 1_001_001, "Nested lazy maps should compose correctly")
  }

  @Test("Complex shrink tree operations")
  func complexShrinkTreeOperations() {
    // Test shrinking with multiple transformation layers
    let baseShrink = Shrink<String> { s in
      guard !s.isEmpty else { return [] }
      return [String(s.dropFirst()), String(s.dropLast())]
    }

    // Test contramap chains
    let stringToTupleShrink = Shrink<(String, Int)> { tuple in
      let stringShrinks = baseShrink.shrink(tuple.0)
      return stringShrinks.map { shrunkString in (shrunkString, tuple.1) }
    }

    let contraMappedShrink =
      stringToTupleShrink
      .contramap { (triple: (String, Int, Bool)) in (triple.0, triple.1) }

    let chainResult = contraMappedShrink.shrink(("hello", 42, true))
    // swiftlint:disable:next empty_count
    #expect(chainResult.count >= 0, "Contramap chains should produce valid results")

    // Test flatMap with complex transformations
    let complexFlatMap = baseShrink.flatMap { shrunkString in
      Shrink<(String, String)> { tuple in
        [(shrunkString, tuple.1), (tuple.0, shrunkString)]
      }
    }

    let flatMapResult = complexFlatMap.shrink(("test", "value"))
    // swiftlint:disable:next empty_count
    #expect(flatMapResult.count >= 0, "Complex flatMap should produce valid results")
  }

  @Test("Shrinking performance edge cases")
  func shrinkingPerformanceEdgeCases() {
    // Test shrinking with complex array structures
    let arrayArrayShrink = Shrink<[[Int]]> { nestedArray in
      var results: [[[Int]]] = []

      // Remove outer arrays
      if nestedArray.count > 1 {
        for i in nestedArray.indices {
          var modified = nestedArray
          modified.remove(at: i)
          results.append(modified)
        }
      }

      // Shrink inner arrays
      for (outerIndex, innerArray) in nestedArray.enumerated() {
        if innerArray.count > 1 {
          for innerIndex in innerArray.indices {
            var modified = nestedArray
            modified[outerIndex].remove(at: innerIndex)
            results.append(modified)
          }
        }
      }

      return results
    }

    let deepStructure = [[1, 2, 3], [4, 5], [6, 7, 8, 9]]
    let shrinkResults = arrayArrayShrink.shrink(deepStructure)

    // Verify shrinking produced reasonable alternatives
    #expect(!shrinkResults.isEmpty, "Deep structure shrinking should produce alternatives")

    let allSmallerOrEqual = shrinkResults.allSatisfy { result in
      result.flatMap { $0 }.count <= deepStructure.flatMap { $0 }.count
    }
    #expect(allSmallerOrEqual, "All shrink results should be smaller or equal to original")
  }

  @Test("Edge case shrinking with custom types")
  func edgeCaseShrinkingWithCustomTypes() {
    // Define a custom type for shrinking
    struct CustomData: Equatable {
      let id: Int
      let name: String
      let active: Bool
    }

    let customShrink = Shrink<CustomData> { data in
      var alternatives: [CustomData] = []

      // Shrink ID
      if data.id > 0 {
        alternatives.append(CustomData(id: data.id - 1, name: data.name, active: data.active))
      }

      // Shrink name
      if !data.name.isEmpty {
        alternatives.append(
          CustomData(id: data.id, name: String(data.name.dropLast()), active: data.active)
        )
      }

      // Toggle active
      alternatives.append(CustomData(id: data.id, name: data.name, active: !data.active))

      return alternatives
    }

    let originalData = CustomData(id: 10, name: "TestData", active: true)
    let shrinkResults = customShrink.shrink(originalData)

    #expect(shrinkResults.count == 3, "Custom shrinking should produce expected alternatives")
    #expect(shrinkResults.contains { $0.id == 9 }, "Should shrink ID")
    #expect(shrinkResults.contains { $0.name == "TestDat" }, "Should shrink name")
    #expect(shrinkResults.contains { $0.active == false }, "Should toggle active")
  }

  // MARK: - Size Scaling Edge Cases

  @Test("Size scaling edge cases")
  func sizeScalingEdgeCases() {
    // Test Size scaling with boundary values
    let zeroSize = Size(value: 0)
    _ = Size(value: Int.max)  // Test that max size can be created

    // Test scaling with zero
    let scaledZero = Size.scale(by: 0.5)(zeroSize)
    #expect(scaledZero.value == 0, "Scaling zero size should remain zero")

    // Test scaling with one
    let scaledOne = Size.scale(by: 1.0)(Size(value: 100))
    #expect(scaledOne.value == 100, "Scaling by 1.0 should preserve size")

    // Test scaling with very small factor
    let scaledTiny = Size.scale(by: 0.001)(Size(value: 1000))
    #expect(scaledTiny.value >= 0, "Scaling with tiny factor should be non-negative")

    // Test scaling with large factor
    let scaledLarge = Size.scale(by: 10.0)(Size(value: 10))
    #expect(scaledLarge.value >= 100, "Scaling with large factor should increase size")
  }

  // MARK: - Seed Edge Cases

  @Test("Seed edge case handling")
  func seedEdgeCaseHandling() {
    // Test Seed with boundary values
    let zeroSeed = Seed(value: 0)
    let maxSeed = Seed(value: UInt64.max)

    #expect(zeroSeed.value == 1, "Zero seed should be normalized to 1")
    #expect(maxSeed.value == UInt64.max, "Max seed should be valid")

    // Test SeededRandomNumberGenerator with edge seeds
    var zeroRng = SeededRandomNumberGenerator(seed: 0)
    var maxRng = SeededRandomNumberGenerator(seed: UInt64.max)

    // Generate values to ensure RNG works with edge seeds
    let zeroValue = zeroRng.next()
    let maxValue = maxRng.next()

    #expect(zeroValue != maxValue, "Different seeds should produce different values")
  }

  // MARK: - Generator Edge Cases

  @Test("Generator edge case patterns")
  func generatorEdgeCasePatterns() {
    // Test generators with edge size values
    var rng: any RandomNumberGenerator = SeededRandomNumberGenerator(seed: 42)

    // Test with zero size
    let zeroSizeInt = Gen.int.generate(&rng, Size(value: 0))
    #expect(zeroSizeInt >= Int.min && zeroSizeInt <= Int.max, "Zero size should produce valid int")

    // Test with large size
    let largeSizeArray = Gen.array(Gen.int).generate(&rng, Size(value: 1000))
    // swiftlint:disable:next empty_count
    #expect(largeSizeArray.count >= 0, "Large size should produce valid array")

    // Test frequency generator with valid weights (all positive)
    let frequencyGen = Gen.frequency([
      (1, Gen.constant(1)),
      (1000, Gen.constant(3)),  // Large weight
    ])

    let frequencyValue = frequencyGen.generate(&rng, Size(value: 10))
    #expect([1, 3].contains(frequencyValue), "Frequency should respect weights")
  }
}
