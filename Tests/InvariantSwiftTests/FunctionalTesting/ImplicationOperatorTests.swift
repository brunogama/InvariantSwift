import Testing
@testable import InvariantSwift

/// Tests for QuickCheck-style ==> implication operator (Phase 3 Plan 1).
///
/// Verifies:
/// 1. Correct semantics (true/false precondition behavior)
/// 2. Short-circuit evaluation
/// 3. PropertyEvaluation overload
/// 4. Operator precedence
/// 5. Integration with Property testing
@Suite("Implication Operator Tests")
struct ImplicationOperatorTests {

  // MARK: - Basic Semantics

  @Test("True precondition with true consequent returns .pass")
  func truePreconditionTrueConsequent() {
    let result: PropertyEvaluation = true ==> true
    #expect(result == .pass)
  }

  @Test("True precondition with false consequent returns .fail")
  func truePreconditionFalseConsequent() {
    let result: PropertyEvaluation = true ==> false
    #expect(result == .fail(reason: nil))
  }

  @Test("False precondition returns .discard regardless of consequent")
  func falsePreconditionDiscards() {
    let result1: PropertyEvaluation = false ==> true
    let result2: PropertyEvaluation = false ==> false
    #expect(result1 == .discard(reason: nil))
    #expect(result2 == .discard(reason: nil))
  }

  // MARK: - Short-Circuit Evaluation

  @Test("Consequent is not evaluated when precondition is false")
  func shortCircuitEvaluation() {
    var consequentEvaluated = false
    let _: PropertyEvaluation =
      false
      ==> {
        consequentEvaluated = true
        return true
      }()
    #expect(!consequentEvaluated, "Consequent should not be evaluated when precondition is false")
  }

  @Test("Consequent IS evaluated when precondition is true")
  func consequentEvaluatedWhenPreconditionTrue() {
    var consequentEvaluated = false
    let _: PropertyEvaluation =
      true
      ==> {
        consequentEvaluated = true
        return true
      }()
    #expect(consequentEvaluated, "Consequent should be evaluated when precondition is true")
  }

  // MARK: - PropertyEvaluation Consequent Overload

  @Test("PropertyEvaluation consequent: .pass returned when precondition true")
  func propertyEvaluationConsequentPass() {
    let result: PropertyEvaluation = true ==> PropertyEvaluation.pass
    #expect(result == .pass)
  }

  @Test("PropertyEvaluation consequent: .fail returned when precondition true")
  func propertyEvaluationConsequentFail() {
    let result: PropertyEvaluation = true ==> PropertyEvaluation.fail(reason: "test reason")
    #expect(result == .fail(reason: "test reason"))
  }

  @Test("PropertyEvaluation consequent: .discard on false precondition")
  func propertyEvaluationConsequentDiscard() {
    let result: PropertyEvaluation = false ==> PropertyEvaluation.pass
    #expect(result == .discard(reason: nil))
  }

  // MARK: - Operator Precedence

  @Test("Operator precedence: comparison operators bind tighter")
  func operatorPrecedenceComparison() {
    // n > 0 ==> property should parse as (n > 0) ==> property
    let n = 5
    let result: PropertyEvaluation = n > 0 ==> true
    #expect(result == .pass)

    let n2 = -5
    let result2: PropertyEvaluation = n2 > 0 ==> true
    #expect(result2 == .discard(reason: nil))
  }

  @Test("Operator precedence: compound conditions work")
  func operatorPrecedenceCompound() {
    let n = 50
    let result: PropertyEvaluation = (n > 0 && n < 100) ==> (n * 2 < 200)
    #expect(result == .pass)
  }

  // MARK: - Chained Implications

  @Test("Chained implications: right associativity")
  func chainedImplications() {
    // a ==> b ==> c means a ==> (b ==> c)
    // false ==> (true ==> false) -> .discard (outer precondition false)
    let result1: PropertyEvaluation = false ==> true ==> false
    #expect(result1 == .discard(reason: nil))

    // true ==> (false ==> anything) -> evaluate inner, which discards
    let result2: PropertyEvaluation = true ==> false ==> true
    #expect(result2 == .discard(reason: nil))

    // true ==> (true ==> false) -> evaluate inner, which fails
    let result3: PropertyEvaluation = true ==> true ==> false
    #expect(result3 == .fail(reason: nil))
  }

  // MARK: - Integration with Property Testing

  @Test("Integration: ==> works in EvaluatingProperty")
  func integrationWithEvaluatingProperty() async {
    let property = EvaluatingProperty(generator: Gen<Int>.int(in: -100...100)) { n in
      n > 0 ==> (n * 2 > n)
    }

    let runner = PropertyRunner(seed: Seed(value: 42))
    let result = await runner.runEvaluatingProperty(
      property,
      config: PropertyConfig(iterations: 100)
    )

    // Should succeed - all positive n satisfy n*2 > n, negatives are discarded
    #expect(result.isSuccess || result.isGaveUp)
  }

  @Test("Integration: ==> properly tracks discards")
  func integrationDiscardTracking() async {
    // Property that discards 99% of inputs
    let property = EvaluatingProperty(generator: Gen<Int>.int(in: 0...99)) { n in
      n == 42 ==> true  // Only n=42 is tested, rest discarded
    }

    let runner = PropertyRunner(seed: Seed(value: 12345))
    let config = PropertyConfig(iterations: 10, maxDiscarded: 1000)
    let result = await runner.runEvaluatingProperty(property, config: config)

    // May succeed or give up depending on whether 42 is generated
    #expect(result.isSuccess || result.isGaveUp)
  }

  // MARK: - Dogfood Tests

  @Test("Dogfood: Implication semantics verified by property test")
  func dogfoodImplicationSemantics() async {
    // Property: For all booleans, implication follows truth table
    let boolGen: Gen<(Bool, Bool)> = Gen<Bool>.bool.zip(Gen<Bool>.bool)
    let property = Property<(Bool, Bool)>(
      generator: boolGen
    ) { tuple in
      let (precond, conseq) = tuple
      let result = precond ==> conseq

      if !precond {
        // False precondition always discards
        return result == .discard(reason: nil)
      } else {
        // True precondition: result matches consequent
        return conseq ? (result == .pass) : (result == .fail(reason: nil))
      }
    }

    let runner = PropertyRunner(seed: Seed(value: 999))
    let result = await runner.runProperty(
      property,
      config: PropertyConfig(iterations: 50)
    )
    #expect(
      result.isSuccess,
      "Implication semantics should hold for all boolean combinations"
    )
  }
}
