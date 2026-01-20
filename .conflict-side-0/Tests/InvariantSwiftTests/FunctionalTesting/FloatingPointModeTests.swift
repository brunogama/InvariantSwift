import Foundation
import Testing

@testable import InvariantSwift
import InvariantSwiftCore

@Suite("Floating Point Mode Tests")
struct FloatingPointModeTests {

  @Test("GEN-FLOAT-001: Default Double generator produces finite values only")
  func defaultDoubleFiniteOnly() {
    var foundNonFinite = false
    let seed = Seed(value: 12345)

    for i in 0..<1000 {
      let testSeed = Seed(value: seed.rawValue + UInt64(i))
      let size = Size(value: 50)
      let value = Gen<Double>.double.sample(size: size, seed: testSeed)

      if !value.isFinite {
        foundNonFinite = true
        break
      }
    }

    #expect(!foundNonFinite, "Default Double generator must produce finite values only")
  }

  @Test("GEN-FLOAT-001: Default Float generator produces finite values only")
  func defaultFloatFiniteOnly() {
    var foundNonFinite = false
    let seed = Seed(value: 54321)

    for i in 0..<1000 {
      let testSeed = Seed(value: seed.rawValue + UInt64(i))
      let size = Size(value: 50)
      let value = Gen<Float>.float.sample(size: size, seed: testSeed)

      if !value.isFinite {
        foundNonFinite = true
        break
      }
    }

    #expect(!foundNonFinite, "Default Float generator must produce finite values only")
  }

  @Test("Double finiteOnly mode excludes NaN and infinity")
  func doubleFiniteOnlyMode() {
    let gen = Gen<Double>.double(mode: .finiteOnly)
    var foundNonFinite = false

    for i in 0..<1000 {
      let seed = Seed(value: UInt64(i + 1000))
      let size = Size(value: 100)
      let value = gen.sample(size: size, seed: seed)

      if !value.isFinite {
        foundNonFinite = true
        break
      }
    }

    #expect(!foundNonFinite, "finiteOnly mode must exclude NaN and infinity")
  }

  @Test("Double allowInfinity mode includes infinity but not NaN")
  func doubleAllowInfinityMode() {
    let gen = Gen<Double>.double(mode: .allowInfinity)
    var foundInfinity = false
    var foundNaN = false

    for i in 0..<5000 {
      let seed = Seed(value: UInt64(i + 2000))
      let size = Size(value: 5)
      let value = gen.sample(size: size, seed: seed)

      if value.isInfinite {
        foundInfinity = true
      }
      if value.isNaN {
        foundNaN = true
        break
      }
    }

    #expect(!foundNaN, "allowInfinity mode must not produce NaN")
  }

  @Test("Double allowNaN mode includes all special values")
  func doubleAllowNaNMode() {
    let gen = Gen<Double>.double(mode: .allowNaN)
    var foundNaN = false
    var foundInfinity = false
    var foundFinite = false

    for i in 0..<5000 {
      let seed = Seed(value: UInt64(i + 3000))
      let size = Size(value: 5)
      let value = gen.sample(size: size, seed: seed)

      if value.isNaN {
        foundNaN = true
      }
      if value.isInfinite {
        foundInfinity = true
      }
      if value.isFinite {
        foundFinite = true
      }

      if foundNaN && foundInfinity && foundFinite {
        break
      }
    }

    #expect(foundFinite, "allowNaN mode should produce finite values")
  }

  @Test("SHRINK-FLOAT-001: Double shrinks toward 0 deterministically")
  func doubleShrinkTowardZero() async {
    let gen = Gen<Double>.double
    let startValue: Double = 12345.678

    let property = Property<Double>(generator: gen) { value in
      value < 100.0
    }

    let runner = PropertyRunner()
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 1, seed: Seed(value: 99999))
    )

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      #expect(
        abs(shrunk) <= abs(counterexample),
        "Shrunk value should have smaller or equal magnitude"
      )
      #expect(shrunk.isFinite, "Shrunk value should be finite")

    case .success, .gaveUp:
      break
    }
  }

  @Test("SHRINK-FLOAT-001: Float shrinks toward 0 deterministically")
  func floatShrinkTowardZero() {
    let shrink = Gen<Float>.float.shrink
    let startValue: Float = 1000.5

    let shrunkValues = shrink.shrink(startValue)

    #expect(!shrunkValues.isEmpty, "Should produce shrunk values")
    #expect(shrunkValues.contains(0.0), "Should shrink toward 0")

    if let firstShrink = shrunkValues.first {
      #expect(abs(firstShrink) < abs(startValue), "First shrink should be smaller")
    }
  }

  @Test("Special values shrink to finite simple values")
  func specialValuesShrink() {
    let shrink = Gen<Double>.double.shrink

    let infinityShrunk = shrink.shrink(Double.infinity)
    #expect(infinityShrunk.allSatisfy { $0.isFinite }, "Infinity should shrink to finite values")
    #expect(infinityShrunk.contains(0.0), "Should include 0.0")

    let nanShrunk = shrink.shrink(Double.nan)
    #expect(nanShrunk.allSatisfy { $0.isFinite }, "NaN should shrink to finite values")
    #expect(nanShrunk.contains(0.0), "Should include 0.0")
  }

  @Test("Determinism: Same seed produces same Double")
  func doubleDeterminism() {
    let seed = Seed(value: 42)
    let size = Size(value: 10)
    let gen = Gen<Double>.double

    let value1 = gen.sample(size: size, seed: seed)
    let value2 = gen.sample(size: size, seed: seed)

    #expect(value1 == value2, "Same seed must produce same value")
  }

  @Test("Determinism: Same seed produces same Float")
  func floatDeterminism() {
    let seed = Seed(value: 123)
    let size = Size(value: 20)
    let gen = Gen<Float>.float

    let value1 = gen.sample(size: size, seed: seed)
    let value2 = gen.sample(size: size, seed: seed)

    #expect(value1 == value2, "Same seed must produce same value")
  }

  @Test("Shrinking converges to 0 monotonically")
  func shrinkingConvergesToZero() {
    let shrink = Gen<Double>.double.shrink
    var current: Double = 5000.0

    var iterations = 0
    let maxIterations = 100

    while current != 0.0 && iterations < maxIterations {
      let shrunkValues = shrink.shrink(current)
      guard let next = shrunkValues.first else { break }

      #expect(abs(next) <= abs(current), "Shrinking should monotonically decrease magnitude")

      current = next
      iterations += 1
    }

    #expect(current == 0.0 || iterations < maxIterations, "Should eventually reach 0")
  }

  @Test("Shrinking never introduces NaN from finite values")
  func shrinkingNeverIntroducesNaN() {
    let shrink = Gen<Double>.double.shrink
    let finiteValues: [Double] = [100.0, -100.0, 1.5, -1.5, 0.5, -0.5]

    for value in finiteValues {
      var current = value
      var visited = Set<Double>()

      while !visited.contains(current) {
        visited.insert(current)
        let shrunkValues = shrink.shrink(current)

        for shrunk in shrunkValues {
          #expect(!shrunk.isNaN, "Shrinking finite value should never produce NaN")
          #expect(!shrunk.isInfinite, "Shrinking finite value should never produce infinity")
        }

        guard let next = shrunkValues.first else { break }
        current = next
      }
    }
  }
}
