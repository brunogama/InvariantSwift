import Testing

@testable import InvariantSwiftAdvanced

@Suite("SMT Examples")
struct SMTExampleTests {
  @Test("SMTExamples prime number constraints builds correctly")
  func testPrimeNumberConstraints() {
    let generator = SMTExamples.primeNumberConstraints()
    _ = generator.constraintBuilder
  }

  @Test("SMTExamples pythagorean triple constraints builds correctly")
  func testPythagoreanTripleConstraints() {
    let generator = SMTExamples.pythagoreanTripleConstraints()
    _ = generator.constraintBuilder
  }

  @Test("Complex nested expression builds correctly")
  func testComplexExpressionBuilding() {
    let variable = SMTExpression.variable("x")
    let zero = SMTExpression.constant(.int(0))
    let hundred = SMTExpression.constant(.int(100))
    let two = SMTExpression.constant(.int(2))
    let positive = SMTExpression.binary(.greaterThan, variable, zero)
    let bounded = SMTExpression.binary(.lessThan, variable, hundred)
    let remainder = SMTExpression.binary(.modulo, variable, two)
    let even = SMTExpression.binary(.equals, remainder, zero)
    let combined = SMTExpression.binary(
      .and,
      positive,
      .binary(.and, bounded, even)
    )
    #expect(combined.description.contains("and"))
    #expect(combined.description.contains(">"))
    #expect(combined.description.contains("<"))
    #expect(combined.description.contains("mod"))
  }
}
