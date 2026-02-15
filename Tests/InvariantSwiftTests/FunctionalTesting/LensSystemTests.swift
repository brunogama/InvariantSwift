import Testing
import Foundation
@testable import InvariantSwift
@testable import InvariantSwiftAdvanced

/// Tests for the lens system integration with FunctionalTesting configuration objects
@Suite("Lens System Integration Tests")
struct LensSystemTests {

  @Test("PropertyConfig lens basic operations")
  func propertyConfigLensBasicOperations() async {
    let config = PropertyConfig.default

    // Test getting values through lenses
    #expect(PropertyConfig.iterationsLens.get(config) == 100)
    #expect(PropertyConfig.maxShrinksLens.get(config) == 1000)
    #expect(PropertyConfig.maxDiscardedLens.get(config) == 1000)
    #expect(PropertyConfig.seedLens.get(config) == nil)

    // Test setting values through lenses
    let updated = PropertyConfig.iterationsLens.set(200, config)
    #expect(updated.iterations == 200)
    #expect(updated.maxShrinks == config.maxShrinks)  // Other fields unchanged

    let withSeed = PropertyConfig.seedLens.set(Seed(value: 42), config)
    #expect(withSeed.seed?.rawValue == 42)
  }

  @Test("PropertyConfig lens over operations")
  func propertyConfigLensOverOperations() async {
    let config = PropertyConfig.default

    // Test transforming values through lenses
    let doubled = PropertyConfig.iterationsLens.over { $0 * 2 }(config)
    #expect(doubled.iterations == 200)

    let halved = PropertyConfig.maxShrinksLens.over { $0 / 2 }(config)
    #expect(halved.maxShrinks == 500)
  }

  @Test("PropertyConfig functional configurations")
  func propertyConfigFunctionalConfigurations() async {
    let config = PropertyConfig.default

    // Test performance config
    let perfConfig = PropertyConfig.performanceConfig(config)
    #expect(perfConfig.iterations == 10000)
    #expect(perfConfig.maxShrinks == 10)
    #expect(perfConfig.maxDiscarded == 100)

    // Test quick config
    let quickConfig = PropertyConfig.quickConfig(config)
    #expect(quickConfig.iterations == 20)
    #expect(quickConfig.maxShrinks == 50)
    #expect(quickConfig.maxDiscarded == 50)
  }

  @Test("Size lens operations")
  func sizeLensOperations() async {
    let size = Size(value: 10)

    // Test getting value
    #expect(Size.valueLens.get(size) == 10)

    // Test setting value
    let newSize = Size.valueLens.set(20, size)
    #expect(newSize.value == 20)

    // Test scaling utility
    let scaled = Size.scale(by: 2.0)(size)
    #expect(scaled.value == 20)

    // Test clamping utility
    let clamped = Size.clamp(to: 1...5)(size)
    #expect(clamped.value == 5)
  }

  @Test("Seed lens operations")
  func seedLensOperations() async {
    let seed = Seed(value: 100)

    // Test getting value
    #expect(Seed.seedValue.get(seed) == 100)

    // Test setting value
    let newSeed = Seed.seedValue.set(200, seed)
    #expect(newSeed.rawValue == 200)

    // Test increment utility
    let incremented = Seed.increment(by: 50)(seed)
    #expect(incremented.rawValue == 150)
  }

  @Test("Function composition with lenses")
  func functionCompositionWithLenses() async {
    let config = PropertyConfig.default

    // Test lens operations with function composition
    let step1 = PropertyConfig.iterationsLens.set(500, config)
    let step2 = PropertyConfig.maxShrinksLens.set(100, step1)

    #expect(step2.iterations == 500)
    #expect(step2.maxShrinks == 100)
    #expect(step2.maxDiscarded == config.maxDiscarded)  // Unchanged

    // Test using the over function
    let doubled = PropertyConfig.iterationsLens.over { $0 * 2 }(config)
    #expect(doubled.iterations == 200)
  }

  @Test(
    "ConfigBuilder pattern",
    .disabled("PropertyConfig is immutable - needs specialized builder")
  )
  func configBuilderPattern() async {
    // NOTE: PropertyConfig has all `let` properties, so WritableKeyPath doesn't work.
    // Needs specialized PropertyConfigBuilder with named methods or lens-based API.
    // Temporarily disabled pending design decision.
    #expect(Bool(false), "Test body disabled - see comment above")
  }

  @Test("Configuration templates")
  func configurationTemplates() async {
    // Test development template
    let devConfig = ConfigTemplate.development
    #expect(devConfig.iterations == 25)
    #expect(devConfig.maxShrinks == 100)
    #expect(devConfig.maxDiscarded == 100)

    // Test CI template
    let ciConfig = ConfigTemplate.ci
    #expect(ciConfig.iterations == 200)
    #expect(ciConfig.maxShrinks == 500)
    #expect(ciConfig.maxDiscarded == 500)

    // Test debug template with seed
    let debugConfig = ConfigTemplate.debug(seed: 12345)
    #expect(debugConfig.iterations == 10)
    #expect(debugConfig.seed?.rawValue == 12345)
  }

  @Test("Prism operations with Optional")
  func prismOperationsWithOptional() async {
    let optionalValue: Int? = 42
    let nilValue: Int? = nil

    // Prism for Optional's Some case
    let somePrism = Prism<Int?, Int>(
      preview: { $0 },
      review: { $0 }
    )

    // Test preview (extract value)
    #expect(somePrism.preview(optionalValue) == 42)
    #expect(somePrism.preview(nilValue) == nil)

    // Test review (construct value)
    #expect(somePrism.review(100) == 100)
  }

  @Test("Prism operations with Result")
  func prismOperationsWithResult() async {
    let successResult: Result<Int, Error> = .success(42)
    let failureResult: Result<Int, Error> = .failure(NSError(domain: "test", code: 1))

    // Prism for Result's success case
    let successPrism = Prism<Result<Int, Error>, Int>(
      preview: { result in
        switch result {
        case .success(let value): return value
        case .failure: return nil
        }
      },
      review: { .success($0) }
    )

    // Prism for Result's failure case
    let failurePrism = Prism<Result<Int, Error>, Error>(
      preview: { result in
        switch result {
        case .success: return nil
        case .failure(let error): return error
        }
      },
      review: { .failure($0) }
    )

    // Test success prism
    #expect(successPrism.preview(successResult) == 42)
    #expect(successPrism.preview(failureResult) == nil)

    // Test failure prism
    #expect(failurePrism.preview(failureResult) != nil)
    #expect(failurePrism.preview(successResult) == nil)
  }

  @Test("Traversal operations with arrays")
  func traversalOperationsWithArrays() async {
    let numbers = [1, 2, 3, 4, 5]

    // Traversal for array elements
    let arrayTraversal = Traversal<[Int], Int>(
      over: { transform in
        { array in array.map(transform) }
      },
      toListOf: { $0 }
    )

    // Test extracting all values
    let allValues = arrayTraversal.toListOf(numbers)
    #expect(allValues == numbers)

    // Test transforming all values
    let doubled = arrayTraversal.over { $0 * 2 }(numbers)
    #expect(doubled == [2, 4, 6, 8, 10])

    // Test setting all values
    let allTens = arrayTraversal.set(10)(numbers)
    #expect(allTens == [10, 10, 10, 10, 10])
  }

  @Test("Traversal operations with dictionaries")
  func traversalOperationsWithDictionaries() async {
    let dict = ["a": 1, "b": 2, "c": 3]

    // Traversal for dictionary values
    let valuesTraversal = Traversal<[String: Int], Int>(
      over: { transform in
        { dict in dict.mapValues(transform) }
      },
      toListOf: { dict in Array(dict.values) }
    )

    // Test extracting all values
    let allValues = Set(valuesTraversal.toListOf(dict))
    #expect(allValues == Set([1, 2, 3]))

    // Test transforming all values
    let doubled = valuesTraversal.over { $0 * 2 }(dict)
    let expectedDoubled = ["a": 2, "b": 4, "c": 6]
    #expect(doubled == expectedDoubled)
  }
}
