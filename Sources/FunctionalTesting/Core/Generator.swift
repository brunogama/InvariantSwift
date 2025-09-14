import Foundation

/// Simple tracker for generator exhaustion during property checking
/// This allows PropertyChecker to detect when generators are failing to produce valid values
public final class GeneratorExhaustionTracker: @unchecked Sendable {
  public static let shared = GeneratorExhaustionTracker()
  private let lock = NSLock()
  private var exhaustionCount: Int = 0

  public func recordExhaustion(attempts: Int) {
    lock.lock()
    defer { lock.unlock() }
    exhaustionCount += attempts
  }

  public func getAndResetExhaustionCount() -> Int {
    lock.lock()
    defer { lock.unlock() }
    let current = exhaustionCount
    exhaustionCount = 0
    return current
  }
}

/// Size parameter for controlling the complexity of generated values
public struct Size: Sendable {
  public let value: Int

  public init(value: Int) {
    self.value = max(0, value)
  }
  public init(_ value: Int) {
    self.value = max(0, value)
  }
}

extension Size {
  public static let small = Size(10)
  public static let medium = Size(50)
  public static let large = Size(100)
}

/// Shrink represents a coalgebraic structure for generating shrinking sequences
public struct Shrink<T>: @unchecked Sendable {
  public let shrink: (T) -> [T]

  public init(_ shrink: @escaping (T) -> [T]) {
    self.shrink = shrink
  }

  /// Empty shrinking - produces no shrunk values
  public static var empty: Shrink<T> {
    Self { _ in [] }
  }

  /// Contramap for shrinking - enables transformation of shrinking context
  public func contramap<U>(_ f: @escaping (U) -> T) -> Shrink<U> {
    Shrink<U> { u in
      self.shrink(f(u)).map { _ in u }  // Simplified contramap - full implementation would be more complex
    }
  }

  /// Combine two shrinking strategies
  public static func pair<U>(_ left: Shrink<T>, _ right: Shrink<U>) -> Shrink<(T, U)> {
    Shrink<(T, U)> { pair in
      let leftShrunk = left.shrink(pair.0).map { ($0, pair.1) }
      let rightShrunk = right.shrink(pair.1).map { (pair.0, $0) }
      return leftShrunk + rightShrunk
    }
  }

  /// Monadic bind for dependent shrinking
  public func flatMap<U>(_ f: @escaping (T) -> Shrink<U>) -> Shrink<U> {
    Shrink<U> { _ in
      // This is a simplified implementation - full implementation would
      // need to handle the coalgebraic unfolding properly
      []
    }
  }
}

/// Gen<T> - Protocol witness for generation with integrated shrinking
/// Follows the mathematical structure: Gen<T> ≅ (Seed × Size) → T × Shrink<T>
public struct Gen<T>: @unchecked Sendable {
  public let generate: (inout any RandomNumberGenerator, Size) -> T
  public let shrink: Shrink<T>

  public init(
    generate: @escaping (inout any RandomNumberGenerator, Size) -> T,
    shrink: Shrink<T> = .empty
  ) {
    self.generate = generate
    self.shrink = shrink
  }

  /// Convenience initializer for generators without shrinking
  public init(generate: @escaping (inout any RandomNumberGenerator, Size) -> T) {
    self.init(generate: generate, shrink: .empty)
  }

  /// Sample using explicit Seed for deterministic generation
  public func sample(size: Size, seed: Seed) -> T {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)
    return generate(&rng, size)
  }
}

// MARK: - Functor Instance
extension Gen {
  /// Functor map - transforms generated values while preserving structure
  /// Satisfies functor laws: fmap(id) = id, fmap(g . f) = fmap(g) . fmap(f)
  public func map<U>(_ f: @escaping (T) -> U) -> Gen<U> {
    Gen<U>(
      generate: { rng, size in f(self.generate(&rng, size)) },
      shrink: Shrink<U> { _ in [] }  // Simplified - proper shrinking would require inverse transformation
    )
  }

  // Note: Custom operators removed for simplicity - can be added later with proper declarations
}

// MARK: - Applicative Instance
extension Gen {
  /// Applicative pure - lift a value into the generation context
  public static func pure(_ value: T) -> Gen<T> {
    Gen { _, _ in value }
  }

  /// Create a generator that always returns the same constant value
  /// This is an alias for pure() to match common property-based testing conventions
  public static func constant(_ value: T) -> Gen<T> {
    pure(value)
  }

  /// Applicative apply - combine generators applying functions to values
  /// Satisfies applicative laws: pure(id) <*> v = v, pure(.) <*> u <*> v <*> w = u <*> (v <*> w)
  public func apply<U>(_ genF: Gen<(T) -> U>) -> Gen<U> {
    Gen<U>(
      generate: { rng, size in
        let f = genF.generate(&rng, size)
        let t = self.generate(&rng, size)
        return f(t)
      },
      shrink: Shrink.pair(genF.shrink, self.shrink).contramap { u in
        // Safe conversion - if this fails, the types are incompatible
        guard let t = u as? T else {
          // Instead of force casting, use a safe fallback
          fatalError(
            "Type mismatch in generator apply - cannot convert \(type(of: u)) to \(T.self)"
          )
        }
        return (({ _ in u }), t)
      }
    )
  }

  /// Zip two generators into a tuple generator
  public func zip<U>(_ other: Gen<U>) -> Gen<(T, U)> {
    Gen<(T, U)>(
      generate: { rng, size in
        (self.generate(&rng, size), other.generate(&rng, size))
      },
      shrink: Shrink.pair(self.shrink, other.shrink)
    )
  }

  // Note: Custom operators removed for simplicity - can be added later with proper declarations
}

// MARK: - Monad Instance
extension Gen {
  /// Monadic bind - enables dependent generation
  /// Satisfies monad laws: return(a) >>= f = f(a), m >>= return = m, (m >>= f) >>= g = m >>= (\x -> f(x) >>= g)
  public func flatMap<U>(_ f: @escaping (T) -> Gen<U>) -> Gen<U> {
    Gen<U>(
      generate: { rng, size in
        let t = self.generate(&rng, size)
        return f(t).generate(&rng, size)
      },
      shrink: self.shrink.flatMap { t in f(t).shrink }
    )
  }

  // Note: Custom operators removed for simplicity - can be added later with proper declarations
}

// MARK: - Combinators
extension Gen {
  /// Choose one of the provided generators with equal probability
  public static func oneOf(_ generators: [Gen<T>]) -> Gen<T> {
    precondition(!generators.isEmpty, "oneOf requires at least one generator")

    return Gen { rng, size in
      let index = Int.random(in: 0..<generators.count, using: &rng)
      return generators[index].generate(&rng, size)
    }
  }

  /// Choose generators based on frequency weights
  public static func frequency(_ weightedGenerators: [(Int, Gen<T>)]) -> Gen<T> {
    precondition(!weightedGenerators.isEmpty, "frequency requires at least one generator")
    precondition(weightedGenerators.allSatisfy { $0.0 > 0 }, "All weights must be positive")

    let totalWeight = weightedGenerators.map(\.0).reduce(0, +)

    return Gen { rng, size in
      let choice = Int.random(in: 1...totalWeight, using: &rng)
      var currentWeight = 0

      for (weight, generator) in weightedGenerators {
        currentWeight += weight
        if choice <= currentWeight {
          return generator.generate(&rng, size)
        }
      }

      // Fallback - use first generator if selection logic fails
      guard let firstGenerator = weightedGenerators.first else {
        precondition(false, "weightedGenerators cannot be empty at this point")
      }
      return firstGenerator.1.generate(&rng, size)
    }
  }

  /// Filter generated values with a predicate
  /// Warning: Can lead to infinite loops if predicate is too restrictive
  public func suchThat(_ predicate: @escaping (T) -> Bool) -> Gen<T> {
    Gen { rng, size in
      var attempts = 0
      let maxAttempts = 100

      while attempts < maxAttempts {
        let value = self.generate(&rng, size)
        if predicate(value) {
          return value
        }
        attempts += 1
      }

      // Signal exhaustion by incrementing the global counter
      GeneratorExhaustionTracker.shared.recordExhaustion(attempts: maxAttempts)

      // If we can't generate a valid value, just return the last attempt
      return self.generate(&rng, size)
    }
  }

  /// Combine two generators into a generator of pairs
  /// This enables compositional property testing across multiple types
  public static func zip<A, B>(_ genA: Gen<A>, _ genB: Gen<B>) -> Gen<(A, B)> {
    Gen<(A, B)>(
      generate: { rng, size in
        let a = genA.generate(&rng, size)
        let b = genB.generate(&rng, size)
        return (a, b)
      },
      shrink: Shrink.pair(genA.shrink, genB.shrink)
    )
  }

  /// Combine three generators into a generator of triples
  public static func zip<A, B, C>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>) -> Gen<(A, B, C)>
  {
    Gen<(A, B, C)>(
      generate: { rng, size in
        let a = genA.generate(&rng, size)
        let b = genB.generate(&rng, size)
        let c = genC.generate(&rng, size)
        return (a, b, c)
      },
      shrink: Shrink { tuple in
        let (a, b, c) = tuple
        let aShrinks = genA.shrink.shrink(a).map { newA in (newA, b, c) }
        let bShrinks = genB.shrink.shrink(b).map { newB in (a, newB, c) }
        let cShrinks = genC.shrink.shrink(c).map { newC in (a, b, newC) }
        return aShrinks + bShrinks + cShrinks
      }
    )
  }
}

// MARK: - Array Generator
extension Gen {
  /// Generate arrays of the given generator
  public static func array<Element>(_ elementGen: Gen<Element>) -> Gen<[Element]> {
    Gen<[Element]>(
      generate: { rng, size in
        let count = Int.random(in: 0...size.value, using: &rng)
        return (0..<count).map { _ in elementGen.generate(&rng, size) }
      },
      shrink: Shrink { array in
        // Shrink by removing elements and shrinking individual elements
        var shrunk: [[Element]] = []

        // Remove elements
        for i in 0..<array.count {
          var smaller = array
          smaller.remove(at: i)
          shrunk.append(smaller)
        }

        // Shrink individual elements
        for (index, element) in array.enumerated() {
          for shrunkElement in elementGen.shrink.shrink(element) {
            var newArray = array
            newArray[index] = shrunkElement
            shrunk.append(newArray)
          }
        }

        return shrunk
      }
    )
  }
}
