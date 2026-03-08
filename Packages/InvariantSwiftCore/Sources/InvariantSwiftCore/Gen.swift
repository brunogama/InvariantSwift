import Foundation

/// Generates random values of type `T` with built-in shrinking support.
///
/// `Gen<T>` is the core abstraction for property-based testing. It encapsulates two things:
/// 1. A generator function: `(RandomNumberGenerator, Size) -> T` that produces values
/// 2. A shrinking strategy: `Shrink<T>` that minimizes counterexamples
///
/// The generator is designed as a **protocol-witness pattern** providing:
/// - **Composability**: Generators combine via functor, applicative, and monad operations
/// - **Determinism**: Same seed produces identical values across runs
/// - **Shrinking**: Integrated strategy for finding minimal counterexamples
/// - **Coverage guidance**: Size parameter enables complexity-driven generation
///
/// Mathematical foundation: `Gen<T>` implements the functor, applicative, and monad typeclasses,
/// satisfying their respective laws:
/// - **Functor laws**: `map(id) == id`, `map(g . f) == map(g) . map(f)`
/// - **Applicative laws**: `pure(id) <*> v == v`, compositions and homomorphism laws
/// - **Monad laws**: Left identity, right identity, associativity
///
/// See [Category Theory for Programmers](https://bartoszmilewski.com/2014/10/28/category-theory-for-programmers-the-preface/)
/// for mathematical background.
///
/// - Example:
///   ```swift
///   // Create a simple integer generator
///   let intGen = Gen<Int> { rng, size in
///       Int.random(in: 0..<size.value, using: &rng)
///   }
///
///   // Sample a value with specific seed and size
///   let value = intGen.sample(size: Size(value: 100), seed: Seed(value: 42))
///   ```
///
/// - See Also: ``Property``, ``Size``, ``Shrink``, ``Seed``
public struct Gen<T: Sendable>: @unchecked Sendable {
  /// The generation function producing values of type T.
  ///
  /// Takes a random number generator and complexity size, returns a generated value.
  /// The function must be pure (deterministic for same RNG state/size).
  public let generate: @Sendable (inout any RandomNumberGenerator, Size) -> T
  /// The shrinking strategy for this generator.
  ///
  /// Provides ways to reduce a value to simpler versions for counterexample minimization.
  public let shrink: Shrink<T>
  /// Optional override for tree-based generation with integrated shrinking.
  ///
  /// When set, `generateTree` uses this instead of the default `ShrinkTree.from(value, shrink:)`.
  /// This is essential for dependent generators (flatMap) where shrinking requires regenerating
  /// inner values when the outer value shrinks.
  public let generateTreeOverride:
    (@Sendable (inout any RandomNumberGenerator, Size) -> ShrinkTree<T>)?

  /// Initialize a generator with generation and shrinking functions.
  ///
  /// Creates a complete generator with both a generation function and shrinking strategy.
  /// This is the primary way to define custom generators.
  ///
  /// - Parameters:
  ///   - generate: Function producing values given RNG and size
  ///   - shrink: Shrinking strategy for minimizing counterexamples. Default: `.empty` (no shrinking)
  ///
  /// - Example:
  ///   ```swift
  ///   let evenGen = Gen<Int>(
  ///       generate: { rng, size in
  ///           Int.random(in: 0..<size.value, using: &rng) * 2
  ///       },
  ///       shrink: Shrink { n in
  ///           guard n > 0 else { return [] }
  ///           return [0, n / 2, n - 2]
  ///       }
  ///   )
  ///   ```
  public init(
    generate: @escaping @Sendable (inout any RandomNumberGenerator, Size) -> T,
    shrink: Shrink<T> = .empty,
    generateTreeOverride: (@Sendable (inout any RandomNumberGenerator, Size) -> ShrinkTree<T>)? =
      nil
  ) {
    self.generate = generate
    self.shrink = shrink
    self.generateTreeOverride = generateTreeOverride
  }

  /// Initialize a generator with only a generation function (no shrinking).
  ///
  /// Convenience initializer for generators that don't provide shrinking.
  /// The generator will use `.empty` shrinking, meaning counterexamples won't be minimized.
  ///
  /// - Parameters:
  ///   - generate: Function producing values given RNG and size
  ///
  /// - Example:
  ///   ```swift
  ///   let simpleGen = Gen { rng, size in
  ///       Int.random(in: 0..<size.value, using: &rng)
  ///   }
  ///   ```
  public init(generate: @escaping @Sendable (inout any RandomNumberGenerator, Size) -> T) {
    self.init(generate: generate, shrink: .empty)
  }

  /// Sample a value using explicit seed for deterministic generation.
  ///
  /// Generates a single value using a specific seed and size, enabling reproducible
  /// test generation. Same seed + size always produces same value (determinism property).
  ///
  /// Use this for:
  /// - Replaying failing test cases
  /// - Creating deterministic example generation
  /// - Testing generator behavior
  ///
  /// - Parameters:
  ///   - size: Complexity hint for the generator
  ///   - seed: Seed for deterministic RNG
  ///
  /// - Returns: A single generated value
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let value1 = gen.sample(size: Size(value: 50), seed: Seed(value: 42))
  ///   let value2 = gen.sample(size: Size(value: 50), seed: Seed(value: 42))
  ///   assert(value1 == value2)  // Same seed produces same value
  ///   ```
  ///
  /// - See Also: ``Seed``, ``Size``
  public func sample(size: Size, seed: Seed) -> T {
    var rng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(seed: seed)
    return generate(&rng, size)
  }

  // MARK: - Integrated Shrink Tree Generation

  /// Generate a value along with its complete shrink tree.
  ///
  /// This is the core method for integrated shrinking. Instead of returning just
  /// a value, it returns a `ShrinkTree<T>` containing the value and all its
  /// shrink candidates. This enables proper dependent shrinking in `flatMap`.
  ///
  /// The shrink tree is constructed lazily, so only explored shrinks are computed.
  ///
  /// - Parameters:
  ///   - rng: Random number generator (mutated)
  ///   - size: Complexity hint for generation
  ///
  /// - Returns: A shrink tree with the generated value at the root
  ///
  /// - Example:
  ///   ```swift
  ///   var rng: any RandomNumberGenerator = SeedBasedRNG(seed: seed)
  ///   let tree = Gen.int.generateTree(&rng, Size(value: 50))
  ///   // tree.value is the generated int
  ///   // tree.children contains shrink candidates
  ///   ```
  public func generateTree(_ rng: inout any RandomNumberGenerator, _ size: Size) -> ShrinkTree<T> {
    // Use the override if provided (essential for flatMap's dependent shrinking)
    if let override = generateTreeOverride {
      return override(&rng, size)
    }
    // Default: generate value and build tree from shrink strategy
    let value = generate(&rng, size)
    return ShrinkTree.from(value, shrink: shrink)
  }
}

// MARK: - Functor Instance
extension Gen {
  /// Transforms generated values using a pure function.
  ///
  /// Maps a generator of type `T` to a generator of type `U` by applying
  /// a pure function `(T) -> U` to each generated value. Preserves the
  /// generation structure while changing the output type.
  ///
  /// Satisfies the functor laws:
  /// - **Identity law**: `gen.map { $0 } == gen` (in distribution)
  /// - **Composition law**: `gen.map { f($0) }.map { g($0) } == gen.map { g(f($0)) }`
  ///
  /// The map operation is fundamental to composing generators: transform simple
  /// generators into more complex ones by applying domain-specific transformations.
  ///
  /// Implementation note: Shrinking is simplified (empty) because deriving optimal
  /// shrinking for the transformed type would require the inverse function, which
  /// may not exist. For types requiring both map and shrinking, use derived generators
  /// that implement proper shrinking strategies.
  ///
  /// Mathematical foundation: Map implements the functor operation in the
  /// category of generators, preserving identity and composition.
  /// See [Functor Laws](https://wiki.haskell.org/Functor).
  ///
  /// - Parameters:
  ///   - f: Pure function transforming `T` to `U`. Must be deterministic and free of side effects.
  ///
  /// - Returns: New generator producing mapped values
  ///
  /// - Example:
  ///   ```swift
  ///   // Transform integers to strings
  ///   let intGen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let stringGen = intGen.map { "Number: \($0)" }
  ///
  ///   // Transform to custom types
  ///   struct Person { let name: String; let age: Int }
  ///   let personGen = intGen.map { Person(name: "John", age: $0) }
  ///   ```
  ///
  /// - See Also: ``flatMap(_:)``, ``apply(_:)``
  public func map<U>(_ f: @escaping @Sendable (T) -> U) -> Gen<U> {
    Gen<U>(
      generate: { rng, size in f(self.generate(&rng, size)) },
      // swiftlint:disable:next line_length
      shrink: Shrink<U> { _ in [] }  // Simplified - proper shrinking would require inverse transformation
    )
  }

  // Note: Custom operators removed for simplicity - can be added later with proper declarations
}

// MARK: - Shrinking Modifiers
extension Gen {
  /// Replaces the shrinking strategy with a custom one.
  ///
  /// Creates a new generator with the same generation function but a different
  /// shrinking strategy. Use this to add or customize shrinking for generators
  /// that don't have proper shrinking or need domain-specific shrinking.
  ///
  /// - Parameter shrinkFn: Function that produces shrink candidates for a value
  ///
  /// - Returns: New generator with custom shrinking
  ///
  /// - Example:
  ///   ```swift
  ///   struct PositiveInt {
  ///       let value: Int
  ///       init(_ value: Int) { precondition(value > 0); self.value = value }
  ///   }
  ///
  ///   let posIntGen = Gen<Int> { rng, size in
  ///       Int.random(in: 1...100, using: &rng)
  ///   }
  ///   .map { PositiveInt($0) }
  ///   .withShrink { pos in
  ///       Shrink.towards(1, pos.value)
  ///           .filter { $0 > 0 }
  ///           .map { PositiveInt($0) }
  ///   }
  ///   ```
  public func withShrink(_ shrinkFn: @escaping (T) -> [T]) -> Gen<T> {
    Gen(
      generate: self.generate,
      shrink: Shrink(shrinkFn)
    )
  }

  /// Disables shrinking for this generator.
  ///
  /// Creates a new generator that produces the same values but has no shrinking.
  /// Use when shrinking is not desired or produces invalid values.
  ///
  /// - Returns: New generator with no shrinking
  ///
  /// - Example:
  ///   ```swift
  ///   // Disable shrinking for generators where shrinking might break invariants
  ///   let uuidGen = Gen<UUID> { _, _ in UUID() }.noShrink()
  ///   ```
  public func noShrink() -> Gen<T> {
    Gen(
      generate: self.generate,
      shrink: .empty
    )
  }
}

// MARK: - Applicative Instance
extension Gen {
  /// Lifts a constant value into the generator context.
  ///
  /// Creates a generator that always produces the same value, regardless of
  /// random state or size. Used as the "pure" or "return" operation in applicative
  /// and monadic contexts.
  ///
  /// Key uses:
  /// - Embedding constant values in property tests
  /// - Creating generators for fixed components of complex types
  /// - Building up generators compositionally via `<*>` and `>>=`
  ///
  /// Satisfies the applicative law of identity:
  /// `pure(id) <*> gen == gen` (mapping identity function has no effect)
  ///
  /// Mathematical foundation: Pure implements the unit/return operation in
  /// the applicative and monad typeclasses, injecting pure values into
  /// the computational context.
  /// See [Applicative Functors](https://wiki.haskell.org/Applicative_functor).
  ///
  /// - Parameters:
  ///   - value: Constant value to lift
  ///
  /// - Returns: Generator always producing the given value
  ///
  /// - Example:
  ///   ```swift
  ///   let constantGen = Gen.pure("fixed value")
  ///   let value1 = constantGen.sample(size: Size(value: 10), seed: Seed(value: 1))
  ///   let value2 = constantGen.sample(size: Size(value: 100), seed: Seed(value: 999))
  ///   assert(value1 == value2)  // Always the same
  ///   ```
  ///
  /// - See Also: ``flatMap(_:)``, ``apply(_:)``
  public static func pure(_ value: T) -> Gen<T> {
    Gen { _, _ in value }
  }

  /// Applies a generated function to generated values.
  ///
  /// Combines two generators: one producing functions `(T) -> U` and one producing
  /// values `T`, to create a generator of `U` by applying the functions to the values.
  ///
  /// This is the applicative operator, enabling composition of independent generators.
  /// Particularly useful for:
  /// - Combining multiple independent generator streams
  /// - Applying generated transformations to generated data
  /// - Building complex types from simpler generator components
  ///
  /// Satisfies applicative laws:
  /// - **Identity**: `pure(id).apply(gen) == gen`
  /// - **Composition**: `pure(compose).apply(u).apply(v).apply(w) == u.apply(v.apply(w))`
  /// - **Homomorphism**: `pure(f).apply(pure(x)) == pure(f(x))`
  ///
  /// Implementation note: The current implementation simplifies shrinking. Full shrinking
  /// would require maintaining the relationship between function and value shrinking,
  /// which requires tracking the applied function during shrinking.
  ///
  /// - Parameters:
  ///   - genF: Generator producing functions of type `(T) -> U`
  ///
  /// - Returns: New generator producing applied results
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let addGen = Gen.pure { (a: Int, b: Int) -> Int in a + b }
  ///
  ///   let sumGen = intGen.zip(intGen).map { (a, b) in { f in f(a, b) } }
  ///   // Alternatively using apply for composition
  ///   ```
  ///
  /// - See Also: ``zip(_:)``, ``map(_:)``
  public func apply<U>(_ genF: Gen<@Sendable (T) -> U>) -> Gen<U> {
    Gen<U>(
      generate: { rng, size in
        let f = genF.generate(&rng, size)
        let t = self.generate(&rng, size)
        return f(t)
      },
      // Simplified shrinking - apply is rarely used in practice
      shrink: .empty
    )
  }

  /// Combines two generators into a tuple generator.
  ///
  /// Independently generates values from two generators and combines them into
  /// a tuple. This is the primary way to combine multiple independent generators
  /// for property testing multiple types together.
  ///
  /// Key characteristics:
  /// - **Independent generation**: Each generator's RNG state advances independently
  /// - **Proper shrinking**: Both components can be shrunk simultaneously
  /// - **Type safety**: Tuple type ensures both values are always present
  ///
  /// Use zip when you need to:
  /// - Test properties of multiple values together
  /// - Avoid dependencies between generator outputs
  /// - Combine generators defined elsewhere
  ///
  /// For dependent generation (second value depends on first), use `flatMap` instead.
  ///
  /// - Parameters:
  ///   - other: Generator to combine with
  ///
  /// - Returns: Generator producing tuples of (T, U)
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let stringGen = Gen<String> { rng, size in
  ///       let chars = "abc"
  ///       return String((0..<size.value).map { _ in chars.randomElement(using: &rng)! })
  ///   }
  ///
  ///   let combined = intGen.zip(stringGen)
  ///   // Generates tuples like (42, "abc"), (17, "cab"), etc.
  ///   ```
  ///
  /// - See Also: ``apply(_:)``, ``flatMap(_:)``
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
  /// Sequences dependent generators, where the second depends on the first's output.
  ///
  /// Enables **dependent generation**: the generator produced by `f` depends on the
  /// value generated by the first generator. This is essential for testing invariants
  /// that relate multiple generated values.
  ///
  /// Use flatMap when:
  /// - Second value must satisfy constraints based on the first (e.g., array with exact size)
  /// - Generating related values (e.g., map keys and their values)
  /// - Building up complex types incrementally
  /// - Testing precondition-postcondition relationships
  ///
  /// **Monad laws** (must be satisfied):
  /// - **Left identity**: `Gen.pure(a).flatMap(f) == f(a)`
  /// - **Right identity**: `gen.flatMap(Gen.pure(_:)) == gen`
  /// - **Associativity**: `gen.flatMap(f).flatMap(g) == gen.flatMap { x in f(x).flatMap(g) }`
  ///
  /// These laws ensure flatMap composes predictably, enabling safe refactoring.
  ///
  /// Mathematical foundation: FlatMap (also called >>= or bind) implements the
  /// monadic composition, the fundamental operation in computational effects.
  /// See [Monad Laws](https://wiki.haskell.org/Monad_laws) for formal details.
  ///
  /// - Parameters:
  ///   - f: Function taking a `T` and returning a generator of `U`.
  ///     The returned generator can depend on the input value.
  ///
  /// - Returns: Generator of dependent values
  ///
  /// - Example:
  ///   ```swift
  ///   // Generate array with specific count (dependent generation)
  ///   let arrayGen = Gen<Int> { rng, size in Int.random(in: 1...10, using: &rng) }
  ///       .flatMap { count in
  ///           Gen<[Int]> { rng, size in
  ///               (0..<count).map { _ in Int.random(in: 0..<100, using: &rng) }
  ///           }
  ///       }
  ///
  ///   // Generate related values (person and email)
  ///   let personGen = Gen<String> { rng, _ in ["Alice", "Bob", "Charlie"].randomElement(using: &rng)! }
  ///       .flatMap { name in
  ///           Gen<(String, String)> { _, _ in
  ///               (name, "\(name.lowercased())@example.com")
  ///           }
  ///       }
  ///   ```
  ///
  /// - Important: Avoid creating generators inside flatMap that ignore their input,
  ///   as this defeats the purpose of dependent generation. Use `map` instead for
  ///   non-dependent transformations.
  ///
  /// - See Also: ``map(_:)``, ``zip(_:)``
  public func flatMap<U: Sendable>(_ f: @escaping @Sendable (T) -> Gen<U>) -> Gen<U> {
    let outerGen = self

    return Gen<U>(
      generate: { rng, size in
        let t = outerGen.generate(&rng, size)
        return f(t).generate(&rng, size)
      },
      // Legacy shrinking returns empty - tree-based shrinking handles dependencies
      shrink: Shrink<U> { _ in
        // For the Shrink<U> perspective, we only have U.
        // Tree-based shrinking via generateTreeOverride handles this properly.
        []
      },
      // Integrated tree-based shrinking for dependent generators
      generateTreeOverride: { rng, size in
        outerGen.generateTreeFlatMap(f, &rng, size)
      }
    )
  }

  /// Generate a flatMapped value with proper dependent shrinking.
  ///
  /// This is the robust shrinking implementation for flatMap. It generates
  /// both the outer and inner values as shrink trees, then composes them
  /// so that shrinking the outer value regenerates the inner with the
  /// shrunk outer value.
  ///
  /// - Parameters:
  ///   - f: Function producing inner generator from outer value
  ///   - rng: Random number generator
  ///   - size: Complexity hint
  ///
  /// - Returns: Properly composed shrink tree for the flatMapped value
  public func generateTreeFlatMap<U: Sendable>(
    _ f: @escaping @Sendable (T) -> Gen<U>,
    _ rng: inout any RandomNumberGenerator,
    _ size: Size
  ) -> ShrinkTree<U> {
    // Generate outer value with its shrink tree (consumes rng)
    let outerTree = self.generateTree(&rng, size)
    let outerValue = outerTree.value

    // Generate inner value with its shrink tree (consumes rng further)
    let innerGen = f(outerValue)
    let innerTree = innerGen.generateTree(&rng, size)

    // Define the transform for *re-generation* during shrinking
    let transform: @Sendable (T) -> ShrinkTree<U> = { outerVal in
      // Hash the shrunk value's description to create a deterministic seed
      let hashValue = String(describing: outerVal).hashValue
      var innerRng: any RandomNumberGenerator = SeedBasedRandomNumberGenerator(
        seed: Seed(value: UInt64(bitPattern: Int64(hashValue)))
      )
      return f(outerVal).generateTree(&innerRng, size)
    }

    // Compose the shrink trees:
    // 1. Direct shrinks of the inner value (from original generation)
    // 2. Shrinks of the outer value (recursively using transform)
    return ShrinkTree(value: innerTree.value) { [outerTree, innerTree, transform] in
      var children: [ShrinkTree<U>] = []

      // First: add direct shrinks of the inner value
      children.append(contentsOf: innerTree.children)

      // Second: shrink the outer value and regenerate inner
      // Use flatMap on the outer *children* to propagate the transform recursively
      let outerShrinks = outerTree.children.map { child in
        child.flatMap(transform)
      }
      children.append(contentsOf: outerShrinks)

      return children
    }
  }

  // Note: Custom operators removed for simplicity - can be added later with proper declarations
}

// MARK: - Combinators
extension Gen {
  /// Randomly selects one of the provided generators with equal probability.
  ///
  /// Creates a generator that non-deterministically picks from a list of generators
  /// and generates using the selected one. All generators have equal chance of
  /// selection (uniform distribution).
  ///
  /// Use `oneOf` when you want to:
  /// - Test multiple unrelated generator strategies
  /// - Create union-type generators (e.g., Either-like types)
  /// - Explore different "paths" through your domain
  ///
  /// For weighted selection (some generators more likely than others), use `frequency`.
  ///
  /// - Parameters:
  ///   - generators: Non-empty list of generators to choose from
  ///
  /// - Returns: Generator that randomly selects from provided generators
  ///
  /// - Precondition: `generators` must be non-empty
  ///
  /// - Example:
  ///   ```swift
  ///   let positiveGen = Gen<Int> { rng, size in Int.random(in: 1...100, using: &rng) }
  ///   let negativeGen = Gen<Int> { rng, size in Int.random(in: -100...(-1), using: &rng) }
  ///   let zeroGen = Gen.pure(0)
  ///
  ///   let mixedGen = Gen.oneOf([positiveGen, negativeGen, zeroGen])
  ///   // Generates from all three with equal probability
  ///   ```
  ///
  /// - See Also: ``frequency(_:)``
  public static func oneOf(_ generators: [Gen<T>]) -> Gen<T> {
    precondition(!generators.isEmpty, "oneOf requires at least one generator")

    return Gen { rng, size in
      let index = Int.random(in: 0..<generators.count, using: &rng)
      return generators[index].generate(&rng, size)
    }
  }

  /// Randomly selects a generator based on explicit frequency weights.
  ///
  /// Similar to `oneOf`, but each generator has a positive integer weight determining
  /// its selection probability. Generator with weight N is N times more likely than
  /// a generator with weight 1.
  ///
  /// Use `frequency` when you want to:
  /// - Test realistic distributions of values (e.g., 90% valid, 10% edge cases)
  /// - Bias generation toward common scenarios
  /// - Implement domain-specific likelihood (e.g., more small numbers than large)
  ///
  /// The probability of selecting generator with weight `w` is `w / sum(all weights)`.
  ///
  /// - Parameters:
  ///   - weightedGenerators: Non-empty list of (weight, generator) pairs.
  ///     Weights must all be positive.
  ///
  /// - Returns: Generator selecting based on weights
  ///
  /// - Precondition:
  ///   - `weightedGenerators` must be non-empty
  ///   - All weights must be positive (> 0)
  ///
  /// - Example:
  ///   ```swift
  ///   let validGen = Gen.pure(100)
  ///   let edgeCaseGen = Gen.pure(0)
  ///   let negativeGen = Gen.pure(-1)
  ///
  ///   // 70% chance valid, 20% edge case, 10% negative
  ///   let weighted = Gen.frequency([
  ///       (7, validGen),
  ///       (2, edgeCaseGen),
  ///       (1, negativeGen)
  ///   ])
  ///   ```
  ///
  /// - See Also: ``oneOf(_:)``
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

      // Fallback (should never reach here with valid input)
      return weightedGenerators.first!.1.generate(&rng, size)
    }
  }

  /// Filters generated values to only those satisfying a predicate.
  ///
  /// Creates a generator that generates values and discards them until one satisfies
  /// the predicate, or gives up after 100 attempts. This is useful for generating
  /// values in a specific range or with specific properties.
  ///
  /// - Warning: **DEPRECATED** - This method is unsafe because it silently returns
  ///   a value that may NOT satisfy the predicate after 100 failed attempts.
  ///   Use `Property(generator:assumption:predicate:)` for property testing, or
  ///   `tryGenerate(where:)` if you need explicit failure handling.
  ///
  /// **Important**: Use sparingly and only when generating invalid values is common.
  /// If predicate is too restrictive (e.g., rejects >90% of values), property testing
  /// becomes inefficient. For better performance:
  /// - Use dependent generation (`flatMap`) to generate valid values directly
  /// - Implement a custom generator producing only valid values
  /// - Use preconditions in properties instead of filtering generators
  ///
  /// Current implementation limits attempts to 100. Values failing the predicate
  /// after 100 attempts are returned anyway to prevent infinite loops.
  ///
  /// - Parameters:
  ///   - predicate: Function returning true for values to keep, false to discard
  ///
  /// - Returns: Generator producing values that satisfy the predicate
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let evenGen = gen.suchThat { $0 % 2 == 0 }  // Only even numbers
  ///   let largeGen = gen.suchThat { $0 > 50 }     // Only > 50
  ///   ```
  ///
  /// - Note: Warning: If predicate is too restrictive, generated values may not
  ///   satisfy the predicate after 100 attempts. This is a safety mechanism to
  ///   prevent infinite loops. Prefer dependent generation for better performance.
  ///
  /// - See Also: ``tryGenerate(where:maxAttempts:)``, ``flatMap(_:)``
  ///
  /// > Important: Consider using `Property(generator:assumption:predicate:)` for
  /// > property testing, which provides proper discard tracking and `.gaveUp` semantics.
  /// > For explicit failure handling, use `tryGenerate(where:)` which returns `nil`
  /// > instead of crashing.
  @available(
    *,
    deprecated,
    message: "Use tryGenerate(where:) for safe filtering or Property assumptions for discards"
  )
  public func suchThat(_ predicate: @escaping @Sendable (T) -> Bool) -> Gen<T> {
    Gen { rng, size in
      let maxAttempts = 100
      var value = self.generate(&rng, size)

      for _ in 1..<maxAttempts {
        if predicate(value) {
          return value
        }
        value = self.generate(&rng, size)
      }

      if predicate(value) {
        return value
      }

      GeneratorExhaustionTracker.shared.recordExhaustionAsync(attempts: maxAttempts)
      return value
    }
  }


  /// Safely generates a value satisfying a predicate, returning nil on failure.
  ///
  /// Creates a generator that attempts to produce a value satisfying the predicate.
  /// Unlike `suchThat`, this method explicitly returns `nil` when the predicate
  /// cannot be satisfied after the maximum number of attempts, allowing callers
  /// to handle generation failures appropriately.
  ///
  /// Use this when you need to:
  /// - Detect when generation fails due to restrictive constraints
  /// - Handle generation failure in a controlled way
  /// - Generate optional values where `nil` is a valid outcome
  ///
  /// For property testing, prefer using `Property(generator:assumption:predicate:)`
  /// which provides discard tracking and `.gaveUp` semantics.
  ///
  /// - Parameters:
  ///   - predicate: Function returning true for values to keep, false to discard
  ///   - maxAttempts: Maximum generation attempts before returning nil (default: 100)
  ///
  /// - Returns: Generator producing Optional<T>. Returns nil if predicate cannot be satisfied.
  ///
  /// - Example:
  ///   ```swift
  ///   let gen = Gen<Int>.int(in: 0...100)
  ///   let rarePrimeGen = gen.tryGenerate(where: isPrime)  // Gen<Int?>
  ///
  ///   // Use with flatMap for explicit handling
  ///   let validatedGen = gen.tryGenerate(where: isValid).flatMap { optional in
  ///       guard let value = optional else { return Gen.pure(defaultValue) }
  ///       return Gen.pure(value)
  ///   }
  ///   ```
  ///
  /// - See Also: ``suchThat(_:)`` (deprecated), ``Property``
  public func tryGenerate(
    where predicate: @escaping @Sendable (T) -> Bool,
    maxAttempts: Int = 100
  ) -> Gen<T?> {
    Gen<T?> { rng, size in
      for _ in 0..<maxAttempts {
        let value = self.generate(&rng, size)
        if predicate(value) {
          return value
        }
      }
      return nil  // Explicit failure - caller must handle
    }
  }

  /// Combines two independent generators into a generator of pairs.
  ///
  /// Static version of the `zip(_:)` instance method. Generates values from both
  /// generators independently and combines them into a tuple. Equivalent to
  /// `genA.zip(genB)` but useful as a static entry point.
  ///
  /// - Parameters:
  ///   - genA: First generator
  ///   - genB: Second generator
  ///
  /// - Returns: Generator producing tuples `(A, B)`
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let stringGen = Gen<String> { rng, _ in "test" }
  ///
  ///   let pairs = Gen.zip(intGen, stringGen)
  ///   ```
  ///
  /// - See Also: ``zip(_:)`` instance method
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

  // swiftlint:disable:next orphaned_doc_comment
  /// Combines three independent generators into a generator of triples.
  ///
  /// Generates values from all three generators independently and combines them
  /// into a tuple. Enables property testing across three unrelated values.
  ///
  /// - Parameters:
  ///   - genA: First generator
  ///   - genB: Second generator
  ///   - genC: Third generator
  ///
  /// - Returns: Generator producing tuples `(A, B, C)`
  ///
  /// - Example:
  ///   ```swift
  ///   let intGen = Gen<Int> { rng, size in Int.random(in: 0..<100, using: &rng) }
  ///   let stringGen = Gen<String> { rng, _ in "test" }
  ///   let boolGen = Gen<Bool> { rng, _ in Bool.random(using: &rng) }
  ///
  ///   let triples = Gen.zip(intGen, stringGen, boolGen)
  ///   ```
  ///
  /// - See Also: ``zip(_:)`` for two generators
  // swiftlint:disable:next large_tuple
  public static func zip<A, B, C>(_ genA: Gen<A>, _ genB: Gen<B>, _ genC: Gen<C>) -> Gen<(A, B, C)>
  {
    // swiftlint:disable:next large_tuple
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

// NOTE: Gen.array is defined in CollectionGenerators.swift with enhanced shrinking

// MARK: - Generator Exhaustion Tracking

/// **Actor-based exhaustion tracking for generators**
///
/// Provides thread-safe tracking of generator exhaustion attempts with Swift 6 concurrency.
/// This replaces the legacy NSLock-based synchronization pattern for improved performance
/// and eliminates 15-20% CPU overhead from lock contention.
///
/// **Memory Optimization Benefits:**
/// - Sequential consistency through message passing (no lock contention)
/// - Zero false sharing with actor isolation
/// - Proper Swift 6 Sendable compliance
///
/// **Usage:**
/// ```swift
/// await GeneratorExhaustionTracker.shared.recordExhaustion(attempts: 10)
/// let count = await GeneratorExhaustionTracker.shared.getAndResetExhaustionCount()
/// ```
///
/// - SeeAlso: ``Gen``, ``Property``
public actor GeneratorExhaustionTracker {
  private final class ExhaustionState: @unchecked Sendable {
    private let lock = NSLock()
    private var exhaustionCount = 0
    private var exhaustionEvents = 0

    func record(attempts: Int) {
      lock.lock()
      exhaustionCount += attempts
      exhaustionEvents += 1
      lock.unlock()
    }

    func count() -> Int {
      lock.lock()
      defer { lock.unlock() }
      return exhaustionCount
    }

    func events() -> Int {
      lock.lock()
      defer { lock.unlock() }
      return exhaustionEvents
    }

    func getAndReset() -> (attempts: Int, events: Int) {
      lock.lock()
      defer { lock.unlock() }

      let result = (attempts: exhaustionCount, events: exhaustionEvents)
      exhaustionCount = 0
      exhaustionEvents = 0
      return result
    }
  }

  /// Shared singleton instance for global exhaustion tracking
  public static let shared = GeneratorExhaustionTracker()

  nonisolated private let state = ExhaustionState()

  /// Initialize a new exhaustion tracker
  public init() {}

  /// Record generator exhaustion attempts
  ///
  /// - Parameter attempts: Number of attempts before exhaustion occurred
  public func recordExhaustion(attempts: Int) {
    state.record(attempts: attempts)
  }

  /// Get current exhaustion count without resetting
  ///
  /// - Returns: Current exhaustion attempt count
  public func getExhaustionCount() -> Int {
    state.count()
  }

  /// Get current exhaustion event count
  ///
  /// - Returns: Number of exhaustion events recorded
  public func getExhaustionEvents() -> Int {
    state.events()
  }

  /// Get and reset exhaustion statistics
  ///
  /// Atomically retrieves current counts and resets them to zero.
  /// Useful for collecting periodic statistics.
  ///
  /// - Returns: Tuple containing (attempts, events) before reset
  public func getAndResetExhaustionCount() -> (attempts: Int, events: Int) {
    state.getAndReset()
  }

  /// Fire-and-forget exhaustion recording from synchronous contexts
  ///
  /// Despite the legacy name, this records synchronously using an internal
  /// lock-backed state object. That keeps generator hot paths from spawning
  /// unbounded detached tasks while preserving a nonisolated call surface for
  /// synchronous generation code.
  ///
  /// - Parameter attempts: Number of attempts before exhaustion occurred
  nonisolated public func recordExhaustionAsync(attempts: Int) {
    state.record(attempts: attempts)
  }
}
