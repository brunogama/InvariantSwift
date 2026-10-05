import Testing
@testable import InvariantSwiftAdvanced

@Suite("SMT serialization and array generation")
struct SMTSerializationTests {
  @Test("SMTConstraint selects logic from sorts and operations")
  func logicSelection() {
    let realConstraint = SMTConstraint(
      expression: .binary(.greaterThan, .variable("x"), .constant(.real(0))),
      variables: [SMTVariableDeclaration(name: "x", sort: .real)]
    )
    let nonlinearConstraint = SMTConstraint(
      expression: .binary(
        .equals,
        .binary(.multiply, .variable("x"), .variable("x")),
        .constant(.int(4))
      ),
      variables: [SMTVariableDeclaration(name: "x", sort: .int)]
    )
    let arrayConstraint = SMTConstraint(
      expression: .binary(
        .equals,
        .binary(.arraySelect, .variable("values"), .constant(.int(0))),
        .constant(.int(1))
      ),
      variables: [SMTVariableDeclaration(name: "values", sort: .array(.int, .int))]
    )

    #expect(realConstraint.toSMTLIB2().hasPrefix("(set-logic QF_LRA)"))
    #expect(nonlinearConstraint.toSMTLIB2().hasPrefix("(set-logic QF_NIA)"))
    #expect(arrayConstraint.toSMTLIB2().hasPrefix("(set-logic QF_AUFLIA)"))
  }

  @Test("SMT arrays use typed encoding and reject ambiguous literals")
  func arrayEncoding() async {
    let values = SMTValue.array([.int(2), .int(4)])
    let emptyBooleans = SMTValue.array([], elementSort: .bool)
    let ambiguous = SMTValue.array([])

    #expect(
      values.description
        == "(store (store ((as const (Array Int Int)) 2) 0 2) 1 4)"
    )
    #expect(emptyBooleans.description == "((as const (Array Int Bool)) false)")
    #expect(ambiguous.description == "|unsupported SMT array constant|")

    let result = await SMTSolver().solve(SMTConstraint(expression: .constant(ambiguous)))
    guard case .error(let message) = result else {
      Issue.record("Expected ambiguous array literal to be rejected")
      return
    }
    #expect(message.contains("explicit element sort"))
  }

  @Test("Array generator preserves constraints, sorts, and model values")
  func arrayGenerator() {
    let elementGenerator = SMTGenerator<Int>.integerInRange(1...9)
    let generator = SMTGenerator<[Int]>.array(size: 3, elementGenerator: elementGenerator)
    let constraint = generator.constraintBuilder(
      SMTVariableDeclaration(name: "unused", sort: .int)
    )

    #expect(constraint.variables.map(\.name) == ["element_0", "element_1", "element_2"])
    #expect(constraint.expression.description.contains("element_0"))
    #expect(constraint.expression.description.contains("element_1"))
    #expect(constraint.expression.description.contains("element_2"))
    #expect(
      generator.valueExtractor([
        "element_0": .int(2),
        "element_1": .int(4),
        "element_2": .int(8),
      ]) == [2, 4, 8]
    )
    #expect(generator.valueExtractor(["element_0": .int(2)]) == nil)

    let booleanElementGenerator = SMTGenerator<Bool>(
      constraintBuilder: { variable in
        SMTConstraint(expression: .variable(variable.name), variables: [variable])
      },
      valueExtractor: { model in
        guard case .bool(let value) = model["x"] else { return nil }
        return value
      },
      variableSort: .bool
    )
    let booleanGenerator = SMTGenerator<[Bool]>.array(
      size: 2,
      elementGenerator: booleanElementGenerator
    )
    let booleanConstraint = booleanGenerator.constraintBuilder(
      SMTVariableDeclaration(name: "unused", sort: .int)
    )
    #expect(booleanConstraint.variables.map { $0.sort.description } == ["Bool", "Bool"])
    #expect(
      booleanGenerator.valueExtractor([
        "element_0": .bool(true),
        "element_1": .bool(false),
      ]) == [true, false]
    )
  }
}
