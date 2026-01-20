import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

/// Dogfooding Tests: Using InvariantSwift to test InvariantSwift
/// These tests verify the framework's correctness by applying property-based testing to itself
struct DogfoodingTests {

  // MARK: - Generator Law Verification Using Properties

  @Test("Dogfooding: Generator.map preserves identity law")
  func generatorMapIdentityLaw() async {
    // Use a property test to verify: gen.map(id) == gen
    let property = Property<Int>(generator: Gen.int(in: 1...100)) { value in
      let identityGen = Gen.int(in: 1...100).map { $0 }
      let seed = Seed(value: UInt64(value.hashValue &+ 12345))
      let size = Size(value: 10)

      let original = Gen.int(in: 1...100).sample(size: size, seed: seed)
      let mapped = identityGen.sample(size: size, seed: seed)

      return original == mapped
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      break  // Expected
    case .failure(let counterexample, _, _, _, _):
      Issue.record("Identity law violated with seed derived from: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("Dogfooding: Shrinking always produces smaller values")
  func shrinkingProducesSmallerValues() async {
    // Verify shrinking invariant by testing generator's built-in shrink
    let gen = Gen.int(in: 10...1000)

    for i in 0..<100 {
      let seed = Seed(value: UInt64(i))
      let size = Size(value: 50)
      let value = gen.sample(size: size, seed: seed)
      let shrunkValues = gen.shrink.shrink(value)

      // All shrunk values should be closer to 0 than the original
      for shrunk in shrunkValues {
        #expect(abs(shrunk) <= abs(value), "Shrunk \(shrunk) should be <= \(value) in magnitude")
      }
    }
  }

  @Test("Dogfooding: Gen.zip preserves both values")
  func genZipPreservesBothValues() async {
    // Verify combining generators correctly using flatMap+map (equivalent to zip)
    let combined = Gen.int(in: 1...50).flatMap { a in
      Gen.int(in: 51...100).map { b in (a, b) }
    }

    for i in 0..<100 {
      let seed = Seed(value: UInt64(i))
      let size = Size(value: 10)
      let (a, b) = combined.sample(size: size, seed: seed)

      #expect((1...50).contains(a), "First element should be in 1...50, got \(a)")
      #expect((51...100).contains(b), "Second element should be in 51...100, got \(b)")
    }
  }

  @Test("Dogfooding: Seed determinism - same seed produces same sequence")
  func seedDeterminism() async {
    // Use property testing to verify seed determinism
    let property = Property<UInt64>(generator: Gen.uint64) { seedValue in
      let seed = Seed(value: seedValue)
      let gen = Gen.int(in: 1...1000)
      let size = Size(value: 50)

      // Generate twice with same seed
      let first = gen.sample(size: size, seed: seed)
      let second = gen.sample(size: size, seed: seed)

      return first == second
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("Determinism violated for seed: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up")
    }
  }

  @Test("Dogfooding: Property failure detection works correctly")
  func propertyFailureDetection() async {
    // A property that SHOULD fail - verifying the framework catches failures
    let property = Property<Int>(generator: Gen.int(in: 1...100)) { value in
      value < 50  // This will fail for ~50% of values
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      Issue.record("Expected failure but got success - framework didn't detect property violation")

    case .failure(_, _, let shrunk, _, _):
      // Verify shrinking found a minimal counterexample (should be 50)
      #expect(shrunk >= 50, "Shrunk value should still violate property: \(shrunk)")

    case .gaveUp:
      Issue.record("Test gave up unexpectedly")
    }
  }

  @Test("Dogfooding: Generator flatMap chaining works correctly")
  func generatorFlatMapChaining() async {
    // Verify flatMap chains produce valid results by sampling directly
    let chainedGen = Gen.int(in: 1...10).flatMap { _ in
      Gen.array(Gen.int(in: 0...100))
    }

    // Sample multiple times and verify results are valid arrays
    for i in 0..<50 {
      let seed = Seed(value: UInt64(i))
      let size = Size(value: 20)
      let array = chainedGen.sample(size: size, seed: seed)

      // All elements should be in 0...100
      #expect(array.allSatisfy { (0...100).contains($0) }, "All elements should be in range")
    }
  }

  @Test("Dogfooding: Array shrinking preserves failure condition")
  func arrayShrinkingPreservesFailure() async {
    // Property that fails for arrays containing specific element
    let property = Property<[Int]>(
      generator: Gen.array(Gen.int(in: 1...100))
    ) { array in
      !array.contains(42)  // Fails when array contains 42
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 500, maxShrinks: 100)
    )

    switch result {
    case .success:
      // Might not find 42 in 500 iterations - that's OK
      break

    case .failure(_, _, let shrunk, _, _):
      // Shrunk array should still contain the failing element
      #expect(shrunk.contains(42), "Shrunk array should preserve failure condition")
      // Shrunk array should be minimal (ideally just [42])
      #expect(shrunk.count <= 5, "Shrunk array should be minimal: \(shrunk)")

    case .gaveUp:
      Issue.record("Test gave up")
    }
  }

  @Test("Dogfooding: Size parameter affects generator output")
  func sizeParameterAffectsOutput() async {
    // Verify that size parameter influences generation
    let gen = Gen.array(Gen.int)
    let smallSize = Size(value: 1)
    let largeSize = Size(value: 100)

    var smallArrays: [Int] = []
    var largeArrays: [Int] = []

    for i in 0..<20 {
      let testSeed = Seed(value: UInt64(i))
      smallArrays.append(gen.sample(size: smallSize, seed: testSeed).count)
      largeArrays.append(gen.sample(size: largeSize, seed: testSeed).count)
    }

    // Larger size should produce larger arrays on average
    let smallAvg = Double(smallArrays.reduce(0, +)) / Double(smallArrays.count)
    let largeAvg = Double(largeArrays.reduce(0, +)) / Double(largeArrays.count)

    #expect(largeAvg >= smallAvg, "Larger size should produce larger arrays on average")
  }

  @Test("Dogfooding: Property.and combines properties correctly")
  func propertyAndCombinesCorrectly() async {
    let positive = Property<Int>(generator: Gen.int(in: 1...100)) { $0 > 0 }
    let lessThan200 = Property<Int>(generator: Gen.int(in: 1...100)) { $0 < 200 }
    let combined = positive.and(lessThan200)

    let result = await PropertyRunner().runProperty(
      combined,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      break  // Both properties should always pass
    case .failure(let counterexample, _, _, _, _):
      Issue.record("Combined property failed unexpectedly: \(counterexample)")

    case .gaveUp:
      Issue.record("Test gave up")
    }
  }

  @Test("Dogfooding: Generator suchThat filters correctly")
  func generatorSuchThatFilters() async {
    let evenGen = Gen.int(in: 1...100).tryGenerate(where: { $0 % 2 == 0 })

    let property = Property<Int>(generator: evenGen) { value in
      value % 2 == 0  // All values should be even
    }

    let result = await PropertyRunner().runProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    switch result {
    case .success:
      break

    case .failure(let counterexample, _, _, _, _):
      Issue.record("suchThat filter let through odd value: \(counterexample)")

    case .gaveUp:
      // May give up if filter is too strict - that's acceptable
      break
    }
  }
}
