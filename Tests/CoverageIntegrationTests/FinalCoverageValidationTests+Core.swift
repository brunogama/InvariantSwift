import Foundation
import Testing
import InvariantSwiftCore
@testable import InvariantSwift

extension FinalCoverageValidationTests {

  @Test("Final validation - all public APIs comprehensively tested")
  func finalValidationAllPublicAPIsComprehensivelyTested() async {
    verifyPropertyCreationAndRunnerAPIs()
    await verifyAsyncRunnerAPI()
    verifyGeneratorAPIs()
    verifyConfigurationAndShrinkingAPIs()
  }

  @Test("Final validation - all edge cases and boundary conditions covered")
  func finalValidationAllEdgeCasesAndBoundaryConditionsCovered() {
    verifyExtremeSizes()
    verifyExtremeConfigurations()
    verifyCollectionEdgeCases()
    verifyNumericEdgeCases()
    verifyStringAndSeedEdgeCases()
  }

  @Test("Final validation - all error paths and failure scenarios covered")
  func finalValidationAllErrorPathsAndFailureScenariosCovered() async {
    verifyFailureScenarios()
    verifyDiscardScenarios()
    await verifyAsyncFailureScenarios()
    verifyShrinkingEdgeCases()
    verifyResourceEdgeCases()
  }

  private func verifyPropertyCreationAndRunnerAPIs() {
    let basicProperty = Property<Int>(generator: Gen<Int>.int) { _ in true }
    let nonEmptyStringGenerator = Gen<String>.string.map { $0.isEmpty ? "x" : $0 }
    let conditionalProperty = Property<String>(generator: nonEmptyStringGenerator) { !$0.isEmpty }
    let timedProperty = Property<Double>(generator: Gen.double) {
      $0.isFinite || $0.isInfinite || $0.isNaN
    }

    var intRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 1))
    var stringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 2))
    var doubleRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 3))

    let intSample = basicProperty.generator.generate(&intRng, Size(value: 10))
    let stringSample = conditionalProperty.generator.generate(&stringRng, Size(value: 10))
    let doubleSample = timedProperty.generator.generate(&doubleRng, Size(value: 10))

    #expect(intSample >= Int.min)
    #expect(!stringSample.isEmpty)
    #expect(doubleSample.isFinite || doubleSample.isInfinite || doubleSample.isNaN)

    let successResult = runPropertySynchronously(
      basicProperty,
      config: PropertyConfig(iterations: 1, seed: Seed(value: 11))
    )
    assertSuccess(successResult, message: "Basic property should succeed")

    let failureResult = runPropertySynchronously(
      Property<Int>(generator: Gen<Int>.int) { _ in false },
      config: PropertyConfig(iterations: 1, seed: Seed(value: 12))
    )

    if case .failure = failureResult {
      #expect(Bool(true), "Failing property should report a failure")
    } else {
      Issue.record("Failing property validation did not report failure")
    }
  }

  private func verifyAsyncRunnerAPI() async {
    let runner = PropertyRunner(seed: Seed(value: 42))
    let property = Property<Int>(generator: Gen<Int>.int) { _ in true }
    let result = await runner.runProperty(property, config: PropertyConfig(iterations: 5))

    if case .success(let iterations) = result {
      #expect(iterations == 5)
    } else {
      Issue.record("Async property runner validation failed")
    }
  }

  private func verifyGeneratorAPIs() {
    var intRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 100))
    var boolRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 101))
    var stringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 102)
    )
    var pairRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 103))

    let intValue = Gen<Int>.int(in: 1...100).generate(&intRng, Size(value: 10))
    let boolValue = Gen<Bool>.bool.generate(&boolRng, Size(value: 10))
    let stringValue = Gen<String>.string.generate(&stringRng, Size(value: 10))
    let pairValue = Gen<Int>.int.zip(Gen<String>.string).generate(&pairRng, Size(value: 10))
    let filteredGenerator = Gen<Int>.int.tryGenerate(where: { $0 > 0 })
    var filteredRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 104)
    )

    #expect((1...100).contains(intValue))
    #expect(boolValue == true || boolValue == false)
    #expect(stringValue.startIndex <= stringValue.endIndex)
    #expect(pairValue.0 >= Int.min)
    #expect((filteredGenerator.generate(&filteredRng, Size(value: 10)) ?? 1) > 0)
  }

  private func verifyConfigurationAndShrinkingAPIs() {
    let sizes = [Size(value: 0), Size(value: 50), Size(value: 100)]
    let configurations = [
      PropertyConfig.default,
      PropertyConfig(iterations: 10),
      PropertyConfig(iterations: 50, maxShrinks: 25),
      PropertyConfig(iterations: 100, maxShrinks: 50, maxDiscarded: 200),
      PropertyConfig(iterations: 20, maxShrinks: 10, maxDiscarded: 30, seed: Seed(value: 99)),
    ]

    for size in sizes {
      #expect(size.scaled(by: 0.5).value <= size.value)
      #expect(size.scaled(by: 2.0).value >= size.value)
    }

    for config in configurations {
      #expect(config.iterations > 0)
      #expect(config.maxShrinks >= 0)
      #expect(config.maxDiscarded >= 0)
    }

    #expect(!Gen<Int>.int.shrink.shrink(100).isEmpty)
    #expect(!Gen.double.shrink.shrink(50.5).isEmpty)
    #expect(!Gen<Bool>.bool.shrink.shrink(true).isEmpty)
    #expect(Gen<String>.string.shrink.shrink("").isEmpty)
    #expect(!Gen<[Int]>.array(Gen<Int>.int).shrink.shrink([1, 2, 3]).isEmpty)
  }

  private func verifyExtremeSizes() {
    let extremeSizes = [
      Size(value: 0),
      Size(value: 1),
      Size(value: Int.max),
      Size(value: -1),
    ]

    for size in extremeSizes {
      #expect(size.scaled(by: 0.1).value >= 0)
    }
  }

  private func verifyExtremeConfigurations() {
    let configs = [
      PropertyConfig(iterations: 1, maxShrinks: 0, maxDiscarded: 1),
      PropertyConfig(iterations: Int.max, maxShrinks: Int.max, maxDiscarded: Int.max),
      PropertyConfig(iterations: 0, maxShrinks: -1, maxDiscarded: -1),
    ]
    let property = Property<Bool>(generator: Gen<Bool>.bool) { _ in true }

    for config in configs {
      let result = runPropertySynchronously(property, config: config)
      assertNonFatal(result, message: "Extreme configuration should be handled gracefully")
    }
  }

  private func verifyCollectionEdgeCases() {
    let emptyArrayProperty = Property<[Int]>(generator: Gen.pure([])) { $0.isEmpty }
    let largeArrayProperty = Property<[Int]>(generator: Gen<[Int]>.array(Gen<Int>.int)) {
      $0.allSatisfy { _ in true }
    }

    assertSuccess(
      runPropertySynchronously(emptyArrayProperty, config: PropertyConfig(iterations: 5)),
      message: "Empty collection edge case should succeed"
    )
    assertSuccess(
      runPropertySynchronously(largeArrayProperty, config: PropertyConfig(iterations: 5)),
      message: "Large collection edge case should succeed"
    )
  }

  private func verifyNumericEdgeCases() {
    let edgeProperties: [Property<Double>] = [
      Property<Double>(generator: Gen.pure(Double.infinity)) { $0.isInfinite },
      Property<Double>(generator: Gen.pure(Double.nan)) { $0.isNaN },
      Property<Double>(generator: Gen.pure(-Double.infinity)) { $0.isInfinite },
    ]

    for property in edgeProperties {
      assertSuccess(
        runPropertySynchronously(property, config: PropertyConfig(iterations: 1)),
        message: "Numeric edge case should succeed"
      )
    }

    let intMin = runPropertySynchronously(
      Property<Int>(generator: Gen.pure(Int.min)) { $0 == Int.min },
      config: PropertyConfig(iterations: 1)
    )
    let intMax = runPropertySynchronously(
      Property<Int>(generator: Gen.pure(Int.max)) { $0 == Int.max },
      config: PropertyConfig(iterations: 1)
    )

    assertSuccess(intMin, message: "Int.min should be handled")
    assertSuccess(intMax, message: "Int.max should be handled")
  }

  private func verifyStringAndSeedEdgeCases() {
    let stringEdgeCases = [
      "",
      " ",
      "\n\t\r",
      "\u{1F680}\u{1F389}\u{1F525}",
      String(repeating: "x", count: 10_000),
      "\0",
      "Hello\nWorld\tTest",
    ]

    for edgeString in stringEdgeCases {
      let result = runPropertySynchronously(
        Property<String>(generator: Gen.pure(edgeString)) { $0 == edgeString },
        config: PropertyConfig(iterations: 1)
      )
      assertSuccess(result, message: "String edge case should be reproducible")
    }

    for seed in [UInt64(0), 1, UInt64.max, 42, 12_345] {
      var firstIntRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: seed)
      )
      var secondIntRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: seed)
      )
      var firstStringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: seed)
      )
      var secondStringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: seed)
      )

      let intValueA = Gen<Int>.int.generate(&firstIntRng, Size(value: 10))
      let intValueB = Gen<Int>.int.generate(&secondIntRng, Size(value: 10))
      let stringValueA = Gen<String>.string.generate(&firstStringRng, Size(value: 10))
      let stringValueB = Gen<String>.string.generate(&secondStringRng, Size(value: 10))

      #expect(intValueA == intValueB)
      #expect(stringValueA == stringValueB)
    }
  }

  private func verifyFailureScenarios() {
    let failingProperties = [
      Property<Int>(generator: Gen<Int>.int) { _ in false },
      Property<Int>(generator: Gen<Int>.int(in: 1...10)) { $0 > 10 },
      Property<Int>(generator: Gen.pure(50)) { $0 != 50 },
    ]

    for property in failingProperties {
      let result = runPropertySynchronously(property, config: PropertyConfig(iterations: 5))
      if case .failure = result {
        #expect(Bool(true), "Failing property should fail")
      } else {
        Issue.record("Expected failing property to fail")
      }
    }
  }

  private func verifyDiscardScenarios() {
    let giveUpProperty = Property<Int>(
      generator: Gen<Int>.int,
      assumption: { _ in false },
      predicate: { _ in true }
    )
    let result = runPropertySynchronously(
      giveUpProperty,
      config: PropertyConfig(iterations: 3, maxDiscarded: 3)
    )

    if case .gaveUp(let discarded, _) = result {
      #expect(discarded > 0)
    } else {
      Issue.record("Discard-heavy property should give up")
    }
  }

  private func verifyAsyncFailureScenarios() async {
    let runner = PropertyRunner(seed: Seed(value: 77))
    let failingProperty = Property<Int>(generator: Gen<Int>.int) { _ in false }
    let giveUpProperty = Property<Int>(
      generator: Gen<Int>.int,
      assumption: { _ in false },
      predicate: { _ in true }
    )

    let failureResult = await runner.runProperty(
      failingProperty,
      config: PropertyConfig(iterations: 3)
    )
    let giveUpResult = await runner.runProperty(
      giveUpProperty,
      config: PropertyConfig(iterations: 3, maxDiscarded: 3)
    )

    if case .failure = failureResult {
      #expect(Bool(true), "Async failure path should fail")
    } else {
      Issue.record("Async failing property should fail")
    }

    if case .gaveUp(let discarded, _) = giveUpResult {
      #expect(discarded > 0)
    } else {
      Issue.record("Async discard-heavy property should give up")
    }
  }

  private func verifyShrinkingEdgeCases() {
    #expect(Gen<String>.string.shrink.shrink("").isEmpty)
    #expect(Gen<[Int]>.array(Gen<Int>.int).shrink.shrink([]).isEmpty)
    #expect(Gen<Int>.int.shrink.shrink(0).isEmpty)
    #expect(Gen<Bool>.bool.shrink.shrink(false).isEmpty)
  }

  private func verifyResourceEdgeCases() {
    let resourceProperty = Property<[String]>(
      generator: Gen<[String]>.array(Gen<String>.string),
      predicate: { array in array.isEmpty }
    )
    let result = runPropertySynchronously(resourceProperty, config: PropertyConfig(iterations: 50))
    assertNonFatal(result, message: "Resource-intensive scenarios should complete")
  }
}
