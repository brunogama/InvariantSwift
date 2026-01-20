import Foundation

// MARK: - forAll Global Functions

/// Create a property from a closure with automatic generator inference.
///
/// This function enables ergonomic property definition using type inference.
/// The generator is derived from the parameter type's `Arbitrary` conformance.
///
/// - Parameter check: Closure taking a generated value and returning Bool
/// - Returns: A property that checks the closure predicate
///
/// - Example:
///   ```swift
///   let property = forAll { (n: Int) in
///     n + 0 == n  // Identity property
///   }
///   ```
///
/// - See Also: ``Generatable``, ``Property``
public func forAll<A: Generatable & Sendable>(
  _ check: @escaping @Sendable (A) -> Bool
) -> Property<A> where A.GeneratorType == Gen<A> {
  Property(
    generator: A.arbitrary,
    predicate: check
  )
}

/// Create a property from a closure returning PropertyEvaluation.
///
/// This overload allows explicit control over pass/fail/discard outcomes
/// using PropertyEvaluation return type.
///
/// - Parameter check: Closure taking a generated value and returning PropertyEvaluation
/// - Returns: An evaluating property that checks the closure
///
/// - Example:
///   ```swift
///   let property = forAll { (n: Int) -> PropertyEvaluation in
///     guard n > 0 else { return .discard(reason: "need positive") }
///     return n * 2 > n ? .pass : .fail(reason: "doubling should increase")
///   }
///   ```
///
/// - See Also: ``PropertyEvaluation``, ``EvaluatingProperty``
public func forAll<A: Generatable & Sendable>(
  _ check: @escaping @Sendable (A) -> PropertyEvaluation
) -> EvaluatingProperty<A> where A.GeneratorType == Gen<A> {
  EvaluatingProperty(
    generator: A.arbitrary,
    evaluate: check
  )
}

// MARK: - Two-Parameter forAll

/// Create a property from a two-parameter closure with type inference.
///
/// Automatically zips the generators from both parameter types.
///
/// - Parameter check: Closure taking two generated values and returning Bool
/// - Returns: A property that checks the closure predicate on pairs
///
/// - Example:
///   ```swift
///   let commutative = forAll { (a: Int, b: Int) in
///     a + b == b + a
///   }
///   ```
///
/// - See Also: ``Generatable``, ``Property``, ``Gen.zip(_:_:)``
public func forAll<A: Generatable & Sendable, B: Generatable & Sendable>(
  _ check: @escaping @Sendable (A, B) -> Bool
) -> Property<(A, B)>
where
  A.GeneratorType == Gen<A>,
  B.GeneratorType == Gen<B>
{
  Property(
    generator: Gen<(A, B)>.zip(A.arbitrary, B.arbitrary),
    predicate: { a, b in check(a, b) }
  )
}

/// Create a property from a two-parameter closure returning PropertyEvaluation.
///
/// - Parameter check: Closure taking two generated values and returning PropertyEvaluation
/// - Returns: An evaluating property for pairs
///
/// - Example:
///   ```swift
///   let property = forAll { (n: Int, d: Int) -> PropertyEvaluation in
///     guard d != 0 else { return .discard(reason: "divisor cannot be zero") }
///     return (n / d) * d == n ? .pass : .fail(reason: "division property failed")
///   }
///   ```
///
/// - See Also: ``PropertyEvaluation``, ``EvaluatingProperty``
public func forAll<A: Generatable & Sendable, B: Generatable & Sendable>(
  _ check: @escaping @Sendable (A, B) -> PropertyEvaluation
) -> EvaluatingProperty<(A, B)>
where
  A.GeneratorType == Gen<A>,
  B.GeneratorType == Gen<B>
{
  EvaluatingProperty(
    generator: Gen<(A, B)>.zip(A.arbitrary, B.arbitrary),
    evaluate: { a, b in check(a, b) }
  )
}

// MARK: - Three-Parameter forAll

/// Create a property from a three-parameter closure with type inference.
///
/// Automatically zips the generators from all three parameter types.
///
/// - Parameter check: Closure taking three generated values and returning Bool
/// - Returns: A property that checks the closure predicate on triples
///
/// - Example:
///   ```swift
///   let associative = forAll { (a: Int, b: Int, c: Int) in
///     (a + b) + c == a + (b + c)
///   }
///   ```
///
/// - See Also: ``Generatable``, ``Property``, ``Gen.zip(_:_:_:)``
public func forAll<
  A: Generatable & Sendable,
  B: Generatable & Sendable,
  C: Generatable & Sendable
>(
  // swiftlint:disable:next large_tuple
  _ check: @escaping @Sendable (A, B, C) -> Bool
) -> Property<(A, B, C)>  // swiftlint:disable:this large_tuple
where
  A.GeneratorType == Gen<A>,
  B.GeneratorType == Gen<B>,
  C.GeneratorType == Gen<C>
{
  Property(
    generator: Gen<(A, B, C)>.zip(  // swiftlint:disable:this large_tuple
      A.arbitrary,
      B.arbitrary,
      C.arbitrary
    ),
    predicate: { a, b, c in check(a, b, c) }
  )
}

// MARK: - Explicit Generator Variants

/// Create a property with an explicit generator and check closure.
///
/// Use this when you need a custom generator rather than the default Arbitrary instance.
///
/// - Parameters:
///   - gen: Custom generator for test values
///   - check: Closure checking the property predicate
/// - Returns: A property using the custom generator
///
/// - Example:
///   ```swift
///   let property = forAll(Gen.int(in: 1...100)) { n in
///     n > 0 && n <= 100
///   }
///   ```
///
/// - See Also: ``Gen``, ``Property``
public func forAll<A: Sendable>(
  _ gen: Gen<A>,
  check: @escaping @Sendable (A) -> Bool
) -> Property<A> {
  Property(
    generator: gen,
    predicate: check
  )
}

/// Create a property with an explicit generator and PropertyEvaluation check.
///
/// - Parameters:
///   - gen: Custom generator for test values
///   - check: Closure returning PropertyEvaluation
/// - Returns: An evaluating property using the custom generator
///
/// - Example:
///   ```swift
///   let property = forAll(Gen.int(in: 0...Int.max)) { n -> PropertyEvaluation in
///     guard n > 0 else { return .discard(reason: "need positive") }
///     return n * 2 > n ? .pass : .fail(reason: nil)
///   }
///   ```
///
/// - See Also: ``Gen``, ``PropertyEvaluation``, ``EvaluatingProperty``
public func forAll<A: Sendable>(
  _ gen: Gen<A>,
  check: @escaping @Sendable (A) -> PropertyEvaluation
) -> EvaluatingProperty<A> {
  EvaluatingProperty(
    generator: gen,
    evaluate: check
  )
}

// MARK: - Explicit Two-Parameter forAll

/// Create a property with two explicit generators.
///
/// - Parameters:
///   - genA: Custom generator for first parameter
///   - genB: Custom generator for second parameter
///   - check: Closure checking the property predicate
/// - Returns: A property using the custom generators
///
/// - Example:
///   ```swift
///   let property = forAll(
///     Gen.int(in: 1...100),
///     Gen.int(in: 1...100)
///   ) { (a, b) in
///     a + b > 0
///   }
///   ```
///
/// - See Also: ``Gen``, ``Property``, ``Gen.zip(_:_:)``
public func forAll<A: Sendable, B: Sendable>(
  _ genA: Gen<A>,
  _ genB: Gen<B>,
  check: @escaping @Sendable (A, B) -> Bool
) -> Property<(A, B)> {
  Property(
    generator: Gen<(A, B)>.zip(genA, genB),
    predicate: { a, b in check(a, b) }
  )
}

/// Create a property with two explicit generators and PropertyEvaluation check.
///
/// - Parameters:
///   - genA: Custom generator for first parameter
///   - genB: Custom generator for second parameter
///   - check: Closure returning PropertyEvaluation
/// - Returns: An evaluating property using the custom generators
///
/// - See Also: ``Gen``, ``PropertyEvaluation``, ``EvaluatingProperty``
public func forAll<A: Sendable, B: Sendable>(
  _ genA: Gen<A>,
  _ genB: Gen<B>,
  check: @escaping @Sendable (A, B) -> PropertyEvaluation
) -> EvaluatingProperty<(A, B)> {
  EvaluatingProperty(
    generator: Gen<(A, B)>.zip(genA, genB),
    evaluate: { a, b in check(a, b) }
  )
}

// MARK: - Explicit Three-Parameter forAll

/// Create a property with three explicit generators.
///
/// - Parameters:
///   - genA: Custom generator for first parameter
///   - genB: Custom generator for second parameter
///   - genC: Custom generator for third parameter
///   - check: Closure checking the property predicate
/// - Returns: A property using the custom generators
///
/// - Example:
///   ```swift
///   let property = forAll(
///     Gen.int(in: 0...10),
///     Gen.int(in: 0...10),
///     Gen.int(in: 0...10)
///   ) { (a, b, c) in
///     (a + b) + c == a + (b + c)
///   }
///   ```
///
/// - See Also: ``Gen``, ``Property``, ``Gen.zip(_:_:_:)``
public func forAll<A: Sendable, B: Sendable, C: Sendable>(
  _ genA: Gen<A>,
  _ genB: Gen<B>,
  _ genC: Gen<C>,
  // swiftlint:disable:next large_tuple
  check: @escaping @Sendable (A, B, C) -> Bool
) -> Property<(A, B, C)> {  // swiftlint:disable:this large_tuple
  Property(
    generator: Gen<(A, B, C)>.zip(genA, genB, genC),  // swiftlint:disable:this large_tuple
    predicate: { a, b, c in check(a, b, c) }
  )
}
