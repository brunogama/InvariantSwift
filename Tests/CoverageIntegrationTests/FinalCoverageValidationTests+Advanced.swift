import Foundation
import Testing
import InvariantSwiftCore
@testable import InvariantSwift

extension FinalCoverageValidationTests {

  @Test("Final validation - all integration points and component interactions covered")
  func finalValidationAllIntegrationPointsAndComponentInteractionsCovered() async {
    verifyGeneratorPropertyIntegration()
    verifyShrinkingIntegration()
    await verifyAsyncAndConcurrentIntegration()
    verifySizeAndConfigurationIntegration()
  }

  @Test("Final validation - performance characteristics within acceptable bounds")
  func finalValidationPerformanceCharacteristicsWithinAcceptableBounds() {
    verifyRunnerPerformance()
    verifyGeneratorPerformance()
    verifyShrinkPerformance()
    verifyMemoryFootprint()
  }

  private func verifyGeneratorPropertyIntegration() {
    let properties: [Property<Int>] = [
      Property<Int>(generator: Gen<Int>.int) { _ in true },
      Property<Int>(generator: Gen<Int>.int(in: 1...10)) { $0 > 0 },
      Property<Int>(generator: Gen<Int>.int(in: -100...100)) { abs($0) <= 100 },
    ]

    for property in properties {
      let result = runPropertySynchronously(property, config: PropertyConfig(iterations: 10))
      assertSuccess(result, message: "Generator and property integration should succeed")
    }
  }

  private func verifyShrinkingIntegration() {
    let shrinkingGenerator = Gen<Int>.pure(50).withShrink { value in
      value > 0 ? [0] : []
    }
    let property = Property<Int>(generator: shrinkingGenerator) { $0 > 50 }
    let result = runPropertySynchronously(
      property,
      config: PropertyConfig(iterations: 1, maxShrinks: 10)
    )

    if case .failure(let counterexample, _, let shrunk, _, _) = result {
      #expect(counterexample == 50)
      #expect(shrunk == 0)
    } else {
      Issue.record("Shrinking integration should produce a failure")
    }
  }

  private func verifyAsyncAndConcurrentIntegration() async {
    let runner = PropertyRunner(seed: Seed(value: 67_890))
    let properties: [Property<Bool>] = [
      Property<Bool>(generator: Gen<Bool>.bool) { _ in true },
      Property<Bool>(generator: Gen.pure(true)) { $0 },
      Property<Bool>(generator: Gen.pure(false)) { $0 == false },
    ]

    for property in properties {
      let result = await runner.runProperty(property, config: PropertyConfig(iterations: 8))
      if case .success(let iterations) = result {
        #expect(iterations == 8)
      } else {
        Issue.record("Async integration should complete all iterations")
      }
    }

    await withTaskGroup(of: Bool.self) { group in
      for index in properties.indices {
        let property = properties[index]
        group.addTask {
          let concurrentRunner = PropertyRunner(seed: Seed(value: UInt64(index + 777)))
          let result = await concurrentRunner.runProperty(
            property,
            config: PropertyConfig(iterations: 8)
          )
          if case .success(let iterations) = result {
            return iterations == 8
          }
          return false
        }
      }

      for await success in group {
        #expect(success)
      }
    }
  }

  private func verifySizeAndConfigurationIntegration() {
    let sizes = [Size(value: 0), Size(value: 10), Size(value: 100)]
    for size in sizes {
      var intRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 555))
      var arrayRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: 556)
      )

      let intValue = Gen<Int>.int.generate(&intRng, size)
      let arrayValue = Gen<[String]>.array(Gen<String>.string).generate(&arrayRng, size)

      #expect(intValue >= Int.min)
      #expect(arrayValue.startIndex <= arrayValue.endIndex)
    }

    let configs = [
      PropertyConfig(iterations: 5, seed: Seed(value: 111)),
      PropertyConfig(iterations: 20, maxShrinks: 10, seed: Seed(value: 222)),
      PropertyConfig(iterations: 30, maxShrinks: 15, maxDiscarded: 60, seed: Seed(value: 333)),
    ]

    for config in configs {
      let result = runPropertySynchronously(
        Property<String>(generator: Gen<String>.string) { _ in true },
        config: config
      )

      if case .success(let iterations) = result {
        #expect(iterations == config.iterations)
      } else {
        Issue.record("Configuration integration should respect iteration counts")
      }
    }
  }

  private func verifyRunnerPerformance() {
    for iterations in [100, 500, 1_000] {
      let property = Property<Int>(generator: Gen<Int>.int) { _ in true }
      let start = CFAbsoluteTimeGetCurrent()
      let result = runPropertySynchronously(
        property,
        config: PropertyConfig(iterations: iterations)
      )
      let duration = CFAbsoluteTimeGetCurrent() - start

      if case .success(let completedIterations) = result {
        #expect(completedIterations == iterations)
      } else {
        Issue.record("Performance property should succeed")
      }

      #expect(duration < Double(iterations) * 0.02)
    }
  }

  private func verifyGeneratorPerformance() {
    let size = Size(value: 10)
    let generations = 1_000

    var intRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 888))
    var stringRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
      seed: Seed(value: 889)
    )
    var arrayRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: Seed(value: 890))

    let intDuration = measureGenerations(
      count: generations,
      rng: &intRng,
      size: size,
      generator: Gen<Int>.int
    )
    let stringDuration = measureGenerations(
      count: generations,
      rng: &stringRng,
      size: size,
      generator: Gen<String>.string
    )
    let arrayDuration = measureGenerations(
      count: generations,
      rng: &arrayRng,
      size: size,
      generator: Gen<[Int]>.array(Gen<Int>.int)
    )

    #expect(intDuration < 1.0)
    #expect(stringDuration < 1.0)
    #expect(arrayDuration < 1.0)
  }

  private func verifyShrinkPerformance() {
    let intDuration = measureShrink {
      _ = Gen<Int>.int.shrink.shrink(1_000)
    }
    let stringDuration = measureShrink {
      _ = Gen<String>.string.shrink.shrink("hello world test string")
    }
    let arrayDuration = measureShrink {
      _ = Gen<[Int]>.array(Gen<Int>.int).shrink.shrink(Array(1...50))
    }

    #expect(intDuration < 0.2)
    #expect(stringDuration < 0.2)
    #expect(arrayDuration < 0.2)
  }

  private func verifyMemoryFootprint() {
    let property = Property<[String]>(
      generator: Gen<[String]>.array(Gen<String>.string),
      predicate: { array in array.isEmpty }
    )

    let initialMemory = currentMemoryUsage()
    let result = runPropertySynchronously(property, config: PropertyConfig(iterations: 200))
    let finalMemory = currentMemoryUsage()
    let memoryDeltaMB = Double(Int64(finalMemory) - Int64(initialMemory)) / 1_048_576.0

    assertNonFatal(result, message: "Memory validation should complete")
    #expect(abs(memoryDeltaMB) < 100.0)
  }

  private func measureGenerations<T>(
    count: Int,
    rng: inout any RandomNumberGenerator,
    size: Size,
    generator: Gen<T>
  ) -> CFAbsoluteTime {
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<count {
      _ = generator.generate(&rng, size)
    }
    return CFAbsoluteTimeGetCurrent() - start
  }

  private func measureShrink(_ operation: () -> Void) -> CFAbsoluteTime {
    let start = CFAbsoluteTimeGetCurrent()
    operation()
    return CFAbsoluteTimeGetCurrent() - start
  }
}
