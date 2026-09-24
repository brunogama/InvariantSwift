import Foundation
import InvariantSwiftCore
import Testing
@testable import InvariantSwift

@Suite("Functor Law Validation")
struct FunctorLawValidationTests {
  @Test("Identity map replays the same generated value")
  func identityLaw() {
    let generator = Gen<Int>.int(in: 1...100)
    let size = Size(value: 10)
    let seed = Seed(value: 42)
    let identity: @Sendable (Int) -> Int = { $0 }

    let original = generator.sample(size: size, seed: seed)
    let mapped = generator.map(identity).sample(size: size, seed: seed)

    #expect(original == mapped)
  }

  @Test("Composed maps replay the same generated value")
  func compositionLaw() {
    let generator = Gen<Int>.int(in: 1...10)
    let size = Size(value: 10)
    let seed = Seed(value: 42)
    let first: @Sendable (Int) -> Int = { $0 * 2 }
    let second: @Sendable (Int) -> String = { "value: \($0)" }

    let composed = generator.map { second(first($0)) }.sample(size: size, seed: seed)
    let sequential = generator.map(first).map(second).sample(size: size, seed: seed)

    #expect(composed == sequential)
  }

  @Test("Validator checks observations instead of returning a placeholder")
  func validatorChecksObservations() {
    let generator = Gen<Int>.int(in: 1...10)
    let valid = generator.validateFunctorLaws(
      iterations: 10,
      seed: Seed(value: 42),
      firstTransform: { $0 * 2 },
      secondTransform: { $0 + 3 }
    )

    #expect(valid)
    #expect(!generator.validateFunctorLaws(iterations: 0))

    let sequence = LockedIntegerSequence()
    let unstableGenerator = Gen<Int> { _, _ in sequence.next() }
    #expect(!unstableGenerator.validateFunctorLaws(iterations: 1))
  }
}

/// Shared mutable state is protected by `lock` on every access.
private final class LockedIntegerSequence: @unchecked Sendable {
  private let lock = NSLock()
  private var value = 0

  func next() -> Int {
    lock.lock()
    defer { lock.unlock() }
    value += 1
    return value
  }
}
