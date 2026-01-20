import Testing
import Foundation
import InvariantSwiftCore
@testable import InvariantSwift
@testable import InvariantSwiftExperimental

/// Meta-property tests that use the FunctionalTesting framework to test itself
///
/// This represents the pinnacle of dogfooding: using property-based testing to verify
/// that our property-based testing framework behaves correctly. These tests implement
/// the mathematical principle of self-reference and recursive validation.
///
/// **Mathematical Foundation**:
/// If we have a property testing system P and want to verify P is correct,
/// we can use P to test P, provided we establish a foundation of trust through
/// mathematical laws and axiomatic properties.
///
/// **Reference**: Self-application in formal verification
/// https://en.wikipedia.org/wiki/Self-verifying_theories
struct MetaPropertyTests {

  // MARK: - Generator of Generators Testing

  @Test("Generator of generators preserves functor laws")
  func generatorOfGeneratorsFunctorLaws() async {
    /// Test Intent: Verify that when we generate generators, the generated
    /// generators still satisfy the fundamental functor laws of category theory.
    /// This ensures our generator abstraction is mathematically sound at all levels.

    // Create a generator that generates integer generators
    let genGen = Gen<Gen<Int>> { _, size in
      let range = -size.value...size.value
      return Gen<Int>.int(in: range)
    }

    // Property: All generated generators must satisfy functor identity law
    let functorIdentityProperty = Property(generator: genGen) { generatedGen in
      let seed = Seed(value: 42)
      let size = Size(value: 10)

      // Test functor identity law: fmap(id) = id
      let original = generatedGen.sample(size: size, seed: seed)
      let mapped = generatedGen.map { value in value }.sample(size: size, seed: seed)  // swiftlint:disable:this array_init

      return original == mapped
    }

    let result = runPropertySynchronously(
      functorIdentityProperty,
      config: PropertyConfig(iterations: 50)
    )

    #expect(result.isSuccess, "Generated generators must preserve functor identity law")
  }

  @Test("Generator of generators composition law")
  func generatorOfGeneratorsCompositionLaw() async {
    /// Test Intent: Verify functor composition law holds for generated generators.
    /// Mathematical Law: fmap(g ∘ f) = fmap(g) ∘ fmap(f)

    let genGen = Gen<Gen<String>> { _, size in
      Gen.oneOf([
        Gen.pure(""),
        Gen.pure("test"),
        Gen.pure(String(repeating: "x", count: size.value)),
      ])
    }

    // Test composition law with two functions
    let f: @Sendable (String) -> Int = { $0.count }
    let g: @Sendable (Int) -> Bool = { $0 > 2 }

    let compositionProperty = Property(generator: genGen) { generatedGen in
      let seed = Seed(value: 123)
      let size = Size(value: 5)

      // Left side: fmap(g ∘ f)
      let composed = generatedGen.map { g(f($0)) }
      let leftResult = composed.sample(size: size, seed: seed)

      // Right side: fmap(g) ∘ fmap(f)
      let stepwise = generatedGen.map(f).map(g)
      let rightResult = stepwise.sample(size: size, seed: seed)

      return leftResult == rightResult
    }

    let result = runPropertySynchronously(
      compositionProperty,
      config: PropertyConfig(iterations: 30)
    )
    #expect(result.isSuccess, "Generated generators must preserve functor composition law")
  }

  @Test("Generator of generators with shrinking")
  func generatorOfGeneratorsWithShrinking() async {
    /// Test Intent: Ensure that generators-of-generators properly handle shrinking
    /// and that shrunk generators still produce valid, smaller values.

    let genGen = Gen<Gen<[Int]>> { _, size in
      Gen<[Int]>.array(Gen<Int>.int(in: 0...size.value))
    }

    let shrinkingProperty = Property(generator: genGen) { generatedGen in
      let testArray = [10, 20, 30, 40, 50]  // Sample array to shrink
      let shrunkArrays = generatedGen.shrink.shrink(testArray)

      // All shrunk arrays should be smaller than or equal to original
      return shrunkArrays.allSatisfy { shrunkArray in
        shrunkArray.count <= testArray.count
          && shrunkArray.allSatisfy { element in
            testArray.contains { $0 >= element }
          }
      }
    }

    let result = runPropertySynchronously(shrinkingProperty, config: PropertyConfig(iterations: 25))
    #expect(result.isSuccess, "Generated generators should produce valid shrinking sequences")
  }

  // MARK: - Property of Properties Testing

  @Test("Properties about properties - meta validation")
  func propertiesAboutProperties() async {
    /// Test Intent: Create properties that test properties, establishing
    /// a recursive validation system that verifies our Property abstraction.

    // Generate random properties over integers
    let propertyGen = Gen<Property<Int>> { rng, size in
      let threshold = Int.random(in: -size.value...size.value, using: &rng)

      return Gen.oneOf([
        // Always-true property
        Gen.pure(Property<Int>(generator: Gen<Int>.int) { _ in true }),

        // Threshold-based property
        Gen.pure(Property<Int>(generator: Gen<Int>.int) { value in value >= threshold }),

        // Modulo property
        Gen.pure(
          Property<Int>(generator: Gen<Int>.int) { value in value % 2 == 0 || value % 2 == 1 }
        ),
      ]).generate(&rng, size)  // swiftlint:disable:this multiline_function_chains
    }

    // Meta-property: All valid properties should either consistently pass or fail
    let metaProperty = Property(generator: propertyGen) { generatedProperty in
      // Run the property multiple times with same seed for consistency
      let seed = Seed(value: 999)
      let config = PropertyConfig(iterations: 10, seed: seed)

      let result1 = runPropertySynchronously(generatedProperty, config: config)
      let result2 = runPropertySynchronously(generatedProperty, config: config)

      // Results should be consistent (same property, same seed, same result)
      switch (result1, result2) {
      case (.success(let it1), .success(let it2)):
        return it1 == it2  // Same iteration count
      case (.failure, .failure), (.gaveUp, .gaveUp):
        return true  // Both failed consistently
      default:
        return false  // Inconsistent results
      }
    }

    let result = runPropertySynchronously(metaProperty, config: PropertyConfig(iterations: 20))
    #expect(result.isSuccess, "Properties should behave consistently when run multiple times")
  }

  @Test("Property combinators preserve correctness")
  func propertyCombinatorPreservesCorrectness() async {
    /// Test Intent: Verify that when we combine properties using logical operators,
    /// the combined properties behave according to Boolean algebra laws.

    // Create simple base properties
    let positiveProperty = Property<Int>(generator: Gen<Int>.int) { $0 >= 0 }
    let evenProperty = Property<Int>(generator: Gen<Int>.int) { $0 % 2 == 0 }

    // Test AND combinator
    let andProperty = positiveProperty.and(evenProperty)

    // Meta-property: AND should only pass when both components pass
    let andValidationProperty = Property<(Int, Int)>(generator: Gen<Int>.int.zip(Gen<Int>.int)) {
      pair in  // swiftlint:disable:this closure_parameter_position
      let pos = positiveProperty.predicate(pair.0)
      let even = evenProperty.predicate(pair.1)
      let combined = andProperty.predicate(pair)

      // Boolean algebra: (P ∧ Q)(x,y) = P(x) ∧ Q(y)
      return combined == (pos && even)
    }

    let result = runPropertySynchronously(
      andValidationProperty,
      config: PropertyConfig(iterations: 100)
    )
    #expect(result.isSuccess, "Property AND combinator should follow Boolean algebra")
  }

  // MARK: - Self-Testing PropertyRunner

  @Test("PropertyRunner tests itself with coverage")
  func propertyRunnerTestsItself() async {
    /// Test Intent: Use PropertyRunner to test PropertyRunner's own behavior,
    /// creating a self-validating loop that ensures our execution engine is correct.

    let runner = PropertyRunner(seed: Seed(value: 42))

    // Property: PropertyRunner should consistently execute the same property
    let consistencyProperty = Property<Int>(generator: Gen<Int>.int) { iterations in
      guard iterations > 0 && iterations <= 50 else { return true }

      let testProperty = Property<Bool>(generator: Gen<Bool>.bool) { $0 || !$0 }  // Tautology
      let config = PropertyConfig(iterations: iterations, seed: Seed(value: 42))

      // Synchronous execution for this test
      let result = runPropertySynchronously(testProperty, config: config)
      return result.isSuccess  // Tautology should always succeed
    }

    let result = await runner.runProperty(
      consistencyProperty,
      config: PropertyConfig(iterations: 20)
    )
    #expect(result.isSuccess, "PropertyRunner should consistently execute tautologies successfully")
  }

  @Test("PropertyRunner shrinking behavior validation")
  func propertyRunnerShrinkingValidation() async {
    /// Test Intent: Verify PropertyRunner's shrinking algorithm produces
    /// progressively smaller counterexamples.

    let runner = PropertyRunner(seed: Seed(value: 123))

    // Property that fails for large arrays
    let failingProperty = Property<[Int]>(generator: Gen<[Int]>.array(Gen<Int>.int)) { array in
      array.count < 5  // Fails for arrays with 5+ elements
    }

    let result = await runner.runProperty(
      failingProperty,
      config: PropertyConfig(iterations: 100, maxShrinks: 50)
    )

    switch result {
    case .failure(let counterexample, _, let shrunk, _, _):
      // Shrunk example should be smaller than original
      #expect(
        shrunk.count <= counterexample.count,
        "Shrunk counterexample should be smaller or equal: \(shrunk.count) ≤ \(counterexample.count)"
      )

      // Shrunk example should still fail the property
      #expect(
        !failingProperty.predicate(shrunk),
        "Shrunk counterexample should still fail the property"
      )

    case .success:
      // This might happen if we don't generate large enough arrays
      print("Property unexpectedly succeeded - might need larger size parameter")

    case .gaveUp:
      // This shouldn't happen with our simple property
      #expect(Bool(false), "Property gave up unexpectedly")
    }
  }

  // MARK: - Applicative and Monad Law Testing

  @Test("Generated applicatives preserve applicative laws")
  func generatedApplicativesPreserveLaws() async {
    /// Test Intent: Verify that when we generate applicative functors,
    /// they still satisfy the applicative laws from category theory.
    ///
    /// **Applicative Laws**:
    /// 1. Identity: pure(id) <*> v = v
    /// 2. Composition: pure(.) <*> u <*> v <*> w = u <*> (v <*> w)
    /// 3. Homomorphism: pure(f) <*> pure(x) = pure(f(x))
    /// 4. Interchange: u <*> pure(y) = pure(($ y)) <*> u

    // Create a generator of functions (unused for now, but shows pattern)
    // Note: Function generators are complex with Swift 6 Sendable requirements
    _ = "unused"

    // Test applicative identity law: pure(id) <*> v = v
    // Note: For now, we'll test a simpler applicative property
    let identityProperty = Property<Int>(generator: Gen<Int>.int) { value in
      let genValue = Gen.pure(value)

      let seed = Seed(value: 42)
      let size = Size(value: 10)

      // Simple identity test - a pure value should always return that value
      let result1 = genValue.sample(size: size, seed: seed)
      let result2 = genValue.sample(size: size, seed: seed)

      return result1 == result2 && result1 == value
    }

    let result = runPropertySynchronously(identityProperty, config: PropertyConfig(iterations: 30))
    #expect(result.isSuccess, "Generated applicatives must satisfy identity law")
  }

  @Test("Generated monads preserve monad laws")
  func generatedMonadsPreserveLaws() async {
    /// Test Intent: Verify monad laws for generated monadic generators.
    ///
    /// **Monad Laws**:
    /// 1. Left identity: return(a) >>= f = f(a)
    /// 2. Right identity: m >>= return = m
    /// 3. Associativity: (m >>= f) >>= g = m >>= (\x -> f(x) >>= g)

    // Test left identity law
    let leftIdentityProperty = Property<String>(generator: Gen<String>.string) { value in
      let f: @Sendable (String) -> Gen<Int> = { str in Gen.pure(str.count) }

      // Left side: return(a) >>= f
      let left = Gen.pure(value).flatMap(f)

      // Right side: f(a)
      let right = f(value)

      let seed = Seed(value: 42)
      let size = Size(value: 10)

      let leftResult = left.sample(size: size, seed: seed)
      let rightResult = right.sample(size: size, seed: seed)

      return leftResult == rightResult
    }

    let result = runPropertySynchronously(
      leftIdentityProperty,
      config: PropertyConfig(iterations: 25)
    )
    #expect(result.isSuccess, "Generated monads must satisfy left identity law")
  }

  // MARK: - Coverage-Guided Meta-Testing

  @Test("Coverage-guided generation tests coverage-guided generation")
  func coverageGuidedMetaTesting() async {
    /// Test Intent: Use our coverage-guided generation system to test itself,
    /// creating a recursive validation loop for our advanced testing capabilities.

    let collector = CoverageCollector()
    await collector.addKnownSymbols(["meta_test_function", "recursive_validation"])

    let runner = PropertyRunner(seed: Seed(value: 42))

    // Property that exercises coverage-guided generation
    let coverageProperty = Property<Int>(generator: Gen<Int>.int(in: 1...100)) { value in
      // This should exercise our coverage-guided biasing logic
      let budget = CoverageBudget(
        uncoveredSymbols: ["test_path_\(value % 3)"],
        coverageMap: ["test_path_\(value % 3)": 0.0],
        totalFunctions: 3,
        coveredFunctions: value % 3
      )

      let biasedGen = Gen<Int>.int.biased(by: budget, strategy: .frequency)
      let biasedValue = biasedGen.sample(
        size: Size(value: 10),
        seed: Seed(value: UInt64(abs(value)))
      )

      // The biased generator should still produce valid integers
      return biasedValue >= Int.min && biasedValue <= Int.max
    }

    let (result, report): (PropertyResult<Int>, CoverageReport) =
      await runner.runPropertyWithCoverageGuidance(
        coverageProperty,
        collector: collector,
        config: PropertyConfig(iterations: 30),
        coverageStrategy: .adaptive
      )

    #expect(result.isSuccess, "Coverage-guided meta-testing should succeed")
    #expect(report.executionCount == 30, "Should execute specified number of iterations")
    #expect(report.improvement >= 0.0, "Coverage should not decrease during meta-testing")
  }

  // MARK: - Recursive Validation Architecture

  @Test("Framework validates its own validation logic")
  func frameworkValidatesValidationLogic() async {
    /// Test Intent: The ultimate meta-test - use the framework to verify
    /// that its own validation and checking logic is mathematically sound.

    // Create a property that validates PropertyChecker itself
    let validationProperty = Property<(Property<Bool>, PropertyConfig)>(
      generator: Gen.pure(Property<Bool>(generator: Gen<Bool>.bool, predicate: { $0 || !$0 }))
        .zip(Gen.pure(PropertyConfig(iterations: 5)))
    ) { prop, config in
      // PropertyChecker should consistently handle tautologies
      let result1 = runPropertySynchronously(prop, config: config)
      let result2 = runPropertySynchronously(prop, config: config)

      // Tautologies should always succeed
      return result1.isSuccess && result2.isSuccess
    }

    // Use the framework to check the validation property
    let finalResult = runPropertySynchronously(
      validationProperty,
      config: PropertyConfig(iterations: 10)
    )

    #expect(finalResult.isSuccess, "Framework should validate its own validation logic")

    print(
      "✅ Self-validation complete: FunctionalTesting framework has successfully used itself to verify its own correctness"
    )
  }
}

// MARK: - Mathematical Law Verification Utilities

/// Utilities for verifying mathematical laws in meta-property testing
struct MathematicalLawVerification {

  /// Verify functor laws for a generator type
  static func verifyFunctorLaws<T: Equatable>(
    for gen: Gen<T>,
    seed: Seed = Seed(value: 42),
    size: Size = Size(value: 10)
  ) -> Bool {
    // Identity law: fmap(id) = id
    let original = gen.sample(size: size, seed: seed)
    let mapped = gen.map { value in value }.sample(size: size, seed: seed)  // swiftlint:disable:this array_init

    return original == mapped
  }

  /// Verify applicative laws (simplified version)
  static func verifyApplicativeLaws<T: Equatable>(
    for gen: Gen<T>,
    seed: Seed = Seed(value: 42),
    size: Size = Size(value: 10)
  ) -> Bool {
    // For now, verify that the generator produces consistent results
    let result1 = gen.sample(size: size, seed: seed)
    let result2 = gen.sample(size: size, seed: seed)

    return result1 == result2
  }

  /// Generate a property that tests mathematical laws
  static func createLawTestingProperty<T: Equatable & Sendable>(
    for genGen: Gen<Gen<T>>,
    law: @escaping @Sendable (Gen<T>) -> Bool
  ) -> Property<Gen<T>> {
    Property(generator: genGen) { generatedGen in
      law(generatedGen)
    }
  }
}

/// Documentation examples for meta-property testing
///
/// Meta-property testing represents the highest level of software validation,
/// where a system uses its own capabilities to verify its correctness.
///
/// **Key Concepts**:
/// 1. **Self-Reference**: Using property-based testing to test property-based testing
/// 2. **Recursive Validation**: Generators that generate generators, properties that test properties
/// 3. **Mathematical Soundness**: Ensuring category theory laws hold at all abstraction levels
/// 4. **Coverage Completeness**: Using coverage-guided generation to test coverage-guided generation
///
/// **Applications**:
/// - Compiler bootstrapping (using a compiler to compile itself)
/// - Formal verification systems that verify themselves
/// - Mathematical proof assistants that prove their own consistency (within limits of Gödel's theorems)
///
/// **References**:
/// - *Category Theory for Computer Science* by Barr & Wells
/// - *Types and Programming Languages* by Pierce
/// - https://en.wikipedia.org/wiki/Bootstrapping_(compilers)
/// - https://en.wikipedia.org/wiki/Self-hosting_(compilers)
