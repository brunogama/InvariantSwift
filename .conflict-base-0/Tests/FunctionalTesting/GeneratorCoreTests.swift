import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Comprehensive tests for core Generator functions to achieve 99%+ code coverage
struct GeneratorCoreTests {

  // MARK: - Generator Creation Tests

  @Test("Gen.pure Generator")
  func genPureGenerator() async {
    let property = Property<Int>(generator: Gen.pure(42)) { value in
      value == 42
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 10)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Gen.pure should always return 42, got: \(counterexample)")

    case .gaveUp:
      Issue.record("Gen.pure test gave up unexpectedly")
    }
  }

  @Test("Gen.oneOf Generator")
  func genOneOfGenerator() async {
    let generators = [Gen.pure(1), Gen.pure(2), Gen.pure(3)]
    let property = Property<Int>(generator: Gen.oneOf(generators)) { value in
      value >= 1 && value <= 3
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Gen.oneOf should only produce 1, 2, or 3, got: \(counterexample)")

    case .gaveUp:
      Issue.record("Gen.oneOf test gave up unexpectedly")
    }
  }

  @Test("Gen.frequency Generator")
  func genFrequencyGenerator() async {
    let frequencies = [(10, Gen.pure(1)), (1, Gen.pure(2))]
    let property = Property<Int>(generator: Gen.frequency(frequencies)) { value in
      value == 1 || value == 2
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Gen.frequency should only produce 1 or 2, got: \(counterexample)")

    case .gaveUp:
      Issue.record("Gen.frequency test gave up unexpectedly")
    }
  }

  // MARK: - Generator Combinator Tests

  @Test("Generator map Function")
  func generatorMapFunction() async {
    let property = Property<String>(generator: Gen.int.map { String($0) }) { stringValue in
      Int(stringValue) != nil  // Should be parseable as Int
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Mapped generator should produce parseable strings, got: \(counterexample)")

    case .gaveUp:
      Issue.record("Map test gave up unexpectedly")
    }
  }

  @Test("Generator flatMap Function")
  func generatorFlatMapFunction() async {
    let property = Property<String>(
      generator: Gen.int.flatMap { n in
        Gen.pure("Number: \(n)")
      }
    ) { stringValue in
      stringValue.hasPrefix("Number: ")
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("FlatMapped generator should produce prefixed strings, got: \(counterexample)")

    case .gaveUp:
      Issue.record("FlatMap test gave up unexpectedly")
    }
  }

  @Test("Generator zip Function")
  func generatorZipFunction() async {
    let property = Property<(Int, String)>(
      generator: Gen.int.zip(Gen.string)
    ) { _, _ in
      // Basic validation that we got both types
      true
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Zip test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Zip test gave up unexpectedly")
    }
  }

  // MARK: - Filtering Tests

  @Test("Generator suchThat Function")
  func generatorSuchThatFunction() async {
    let property = Property<Int>(
      generator: Gen.int.suchThat { $0 > 0 }
    ) { value in
      value > 0
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("SuchThat test failed - non-positive value: \(counterexample)")

    case .gaveUp:
      // This can happen if too many values are filtered out
      break
    }
  }

  // MARK: - Apply Function Test

  @Test("Generator apply Function")
  func generatorApplyFunction() async {
    let functionGen = Gen.pure { (x: Int) in String(x) }
    let property = Property<String>(
      generator: Gen.int.apply(functionGen)
    ) { stringValue in
      Int(stringValue) != nil  // Should be parseable as Int
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Apply test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Apply test gave up unexpectedly")
    }
  }

  // MARK: - Size Structure Tests

  @Test("Size struct behavior")
  func sizeStructBehavior() async {
    // Test Size struct creation and properties
    let sizes = [Size(value: -1), Size(value: 0), Size(value: 10), Size(value: 100)]

    for size in sizes {
      #expect(size.value >= 0, "Size should never be negative, got: \(size.value)")
    }

    // Test predefined sizes
    #expect(Size.small.value == 10)
    #expect(Size.medium.value == 50)
    #expect(Size.large.value == 100)
  }

  // MARK: - Shrink Structure Tests

  @Test("Shrink empty behavior")
  func shrinkEmptyBehavior() async {
    let emptyShrink = Shrink<Int>.empty
    let result = emptyShrink.shrink(42)
    #expect(result.isEmpty, "Empty shrink should produce no values")
  }

  @Test("Shrink tree BFS behavior")
  func shrinkTreeBFSBehavior() async {
    // Test ShrinkTree BFS search (replaces deprecated contramap test)
    let intShrink = Shrink<Int> { n in n == 0 ? [] : [0, n / 2] }
    let tree = ShrinkTree.from(100, shrink: intShrink)

    let minimal = tree.findMinimal(budget: 50) { $0 >= 0 }
    #expect(minimal != nil, "ShrinkTree should find minimal value")
    #expect(minimal == 0, "BFS should find 0 as the minimal value >= 0")
  }

  @Test("Shrink pair behavior")
  func shrinkPairBehavior() async {
    let leftShrink = Shrink<Int> { n in n == 0 ? [] : [0] }
    let rightShrink = Shrink<String> { s in s.isEmpty ? [] : [""] }
    let pairShrink = Shrink.pair(leftShrink, rightShrink)

    let result = pairShrink.shrink((5, "test"))
    #expect(!result.isEmpty, "Pair shrink should produce shrunk values")
  }

  // MARK: - Complex Generator Composition Tests

  @Test("Nested Generator Composition")
  func nestedGeneratorComposition() async {
    let property = Property<String>(
      generator: Gen.int
        .map { $0 * 2 }
        .map { String($0) }
        .flatMap { s in Gen.pure("Value: \(s)") }
    ) { result in
      result.hasPrefix("Value: ") && result.contains(where: { $0.isNumber })
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Complex composition test failed with: \(counterexample)")

    case .gaveUp:
      break
    }
  }

  @Test("Recursive Generator Composition")
  func recursiveGeneratorComposition() async {
    // Test recursive generator composition
    func recursiveListGen(depth: Int) -> Gen<[Int]> {
      if depth <= 0 {
        return Gen.pure([])
      }
      return Gen.oneOf([
        Gen.pure([]),
        Gen.int.flatMap { n in
          recursiveListGen(depth: depth - 1).map { rest in
            [n] + rest
          }
        },
      ])
    }

    let property = Property<[Int]>(
      generator: recursiveListGen(depth: 3)
    ) { list in
      list.count <= 10  // Reasonable size limit
    }
    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 30)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Recursive composition test failed with list size: \(counterexample.count)")

    case .gaveUp:
      Issue.record("Recursive composition test gave up unexpectedly")
    }
  }

  // MARK: - Size Parameter Testing

  @Test("Size Parameter Effects")
  func sizeParameterEffects() async {
    let property = Property<[Int]>(generator: Gen.array(Gen.int)) { _ in
      // This test exercises size parameter in array generation
      true
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success: break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Size parameter test failed with: \(counterexample)")

    case .gaveUp:
      Issue.record("Size parameter test gave up unexpectedly")
    }
  }
}
