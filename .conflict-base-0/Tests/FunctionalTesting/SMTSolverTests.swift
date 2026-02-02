/// SMTSolverTests - Comprehensive tests for SMT solver integration
///
/// Verifies SMTExpression, SMTConstraint, SMTSolver, SMTGenerator,
/// and PathCondition functionality.

import Testing
import Foundation
import InvariantCore
@testable import InvariantSwift

@Suite("SMT Solver Integration")
struct SMTSolverTests {

  // MARK: - SMTExpression Tests

  @Test("SMTExpression variable description")
  func testVariableDescription() {
    let expr = SMTExpression.variable("x")
    #expect(expr.description == "x")
  }

  @Test("SMTExpression constant description")
  func testConstantDescription() {
    let intExpr = SMTExpression.constant(.int(42))
    #expect(intExpr.description == "42")

    let boolExpr = SMTExpression.constant(.bool(true))
    #expect(boolExpr.description == "true")

    let realExpr = SMTExpression.constant(.real(3.14))
    #expect(realExpr.description.contains("3.14"))
  }

  @Test("SMTExpression binary operation description")
  func testBinaryOpDescription() {
    let expr = SMTExpression.binary(
      .plus,
      .variable("x"),
      .constant(.int(1))
    )
    #expect(expr.description == "(+ x 1)")
  }

  @Test("SMTExpression unary operation description")
  func testUnaryOpDescription() {
    let expr = SMTExpression.unary(.not, .variable("x"))
    #expect(expr.description == "(not x)")
  }

  @Test("SMTExpression function application description")
  func testFunctionDescription() {
    let expr = SMTExpression.function("abs", [.variable("x")])
    #expect(expr.description == "(abs x)")
  }

  @Test("SMTExpression quantified description")
  func testQuantifiedDescription() {
    let expr = SMTExpression.quantified(
      .forall,
      [("x", .int)],
      .binary(.greaterThan, .variable("x"), .constant(.int(0)))
    )
    #expect(expr.description.contains("forall"))
    #expect(expr.description.contains("(x Int)"))
  }

  // MARK: - SMTValue Tests

  @Test("SMTValue descriptions are correct")
  func testSMTValueDescriptions() {
    #expect(SMTValue.bool(true).description == "true")
    #expect(SMTValue.bool(false).description == "false")
    #expect(SMTValue.int(42).description == "42")
    #expect(SMTValue.string("hello").description == "\"hello\"")
  }

  // MARK: - SMTSort Tests

  @Test("SMTSort descriptions are correct")
  func testSMTSortDescriptions() {
    #expect(SMTSort.bool.description == "Bool")
    #expect(SMTSort.int.description == "Int")
    #expect(SMTSort.real.description == "Real")
    #expect(SMTSort.string.description == "String")
    #expect(SMTSort.bitVector(32).description == "(_ BitVec 32)")
    #expect(SMTSort.array(.int, .bool).description == "(Array Int Bool)")
  }

  // MARK: - SMTBinaryOp Tests

  @Test("SMTBinaryOp raw values are correct")
  func testBinaryOpRawValues() {
    #expect(SMTBinaryOp.and.rawValue == "and")
    #expect(SMTBinaryOp.or.rawValue == "or")
    #expect(SMTBinaryOp.equals.rawValue == "=")
    #expect(SMTBinaryOp.plus.rawValue == "+")
    #expect(SMTBinaryOp.lessThan.rawValue == "<")
  }

  // MARK: - SMTConstraint Tests

  @Test("SMTConstraint initializes correctly")
  func testConstraintInitialization() {
    let constraint = SMTConstraint(
      expression: .binary(.greaterThan, .variable("x"), .constant(.int(0))),
      variables: [SMTVariableDeclaration(name: "x", sort: .int)]
    )

    #expect(constraint.variables.count == 1)
    #expect(constraint.variables[0].name == "x")
  }

  @Test("SMTConstraint generates valid SMTLIB2")
  func testSMTLIB2Generation() {
    let constraint = SMTConstraint(
      expression: .binary(.greaterThan, .variable("x"), .constant(.int(0))),
      variables: [SMTVariableDeclaration(name: "x", sort: .int)]
    )

    let smtlib2 = constraint.toSMTLIB2()

    #expect(smtlib2.contains("(set-logic"))
    #expect(smtlib2.contains("(declare-fun x () Int)"))
    #expect(smtlib2.contains("(assert (> x 0))"))
    #expect(smtlib2.contains("(check-sat)"))
    #expect(smtlib2.contains("(get-model)"))
  }

  // MARK: - SMTSolverConfig Tests

  @Test("SMTSolverConfig has correct defaults")
  func testSolverConfigDefaults() {
    let config = SMTSolverConfig()
    #expect(config.solverPath == "z3")
    #expect(config.memoryLimit == nil)
    #expect(config.randomSeed == nil)
  }

  @Test("SMTSolverConfig static configs exist")
  func testSolverConfigStatics() {
    let z3Config = SMTSolverConfig.z3
    #expect(z3Config.solverPath == "z3")

    let cvc4Config = SMTSolverConfig.cvc4
    #expect(cvc4Config.solverPath == "cvc4")
  }

  // MARK: - SMTSolver Tests

  @Test("SMTSolver initializes with config")
  func testSolverInitialization() async {
    let solver = SMTSolver(config: .z3)
    let stats = await solver.getStatistics()

    #expect(stats.solveCount == 0)
    #expect(stats.solverPath == "z3")
  }

  // MARK: - SMTExpression Extension Tests

  @Test("SMTExpression range constraint")
  func testRangeConstraint() {
    let expr = SMTExpression.range(
      .variable("x"),
      min: .int(0),
      max: .int(100)
    )

    #expect(expr.description.contains("and"))
    #expect(expr.description.contains("<="))
  }

  @Test("SMTExpression distinct constraint")
  func testDistinctConstraint() {
    let expressions: [SMTExpression] = [
      .variable("x"),
      .variable("y"),
      .variable("z"),
    ]

    let distinct = SMTExpression.distinct(expressions)

    #expect(distinct.description.contains("distinct"))
  }

  @Test("SMTExpression distinct with single element")
  func testDistinctSingleElement() {
    let expressions: [SMTExpression] = [.variable("x")]
    let distinct = SMTExpression.distinct(expressions)

    #expect(distinct.description == "true")
  }

  // MARK: - SMTVariableDeclaration Tests

  @Test("SMTVariableDeclaration stores name and sort")
  func testVariableDeclaration() {
    let decl = SMTVariableDeclaration(name: "myVar", sort: .real)

    #expect(decl.name == "myVar")
    #expect(decl.sort.description == "Real")
  }

  // MARK: - SMTResult Tests

  @Test("SMTResult satisfiable case")
  func testResultSatisfiable() {
    let result = SMTResult.satisfiable(["x": .int(42)])

    switch result {
    case .satisfiable(let model):
      #expect(model["x"] != nil)
      if case .int(let value) = model["x"] {
        #expect(value == 42)
      }

    default:
      Issue.record("Expected satisfiable result")
    }
  }

  @Test("SMTResult enum cases exist")
  func testResultCases() {
    // Just verify the enum cases exist and can be created
    let sat = SMTResult.satisfiable([:])
    let unsat = SMTResult.unsatisfiable
    let unknown = SMTResult.unknown
    let timeout = SMTResult.timeout
    let error = SMTResult.error("test error")

    // Verify they're distinct
    if case .satisfiable = sat {} else { Issue.record("Expected satisfiable") }
    if case .unsatisfiable = unsat {} else { Issue.record("Expected unsatisfiable") }
    if case .unknown = unknown {} else { Issue.record("Expected unknown") }
    if case .timeout = timeout {} else { Issue.record("Expected timeout") }
    if case .error = error {} else { Issue.record("Expected error") }
  }

  // MARK: - PathCondition Tests

  @Test("PathCondition stores conditions and variables")
  func testPathConditionStorage() {
    let conditions: [SMTExpression] = [
      .binary(.greaterThan, .variable("x"), .constant(.int(0))),
      .binary(.lessThan, .variable("x"), .constant(.int(100))),
    ]

    let variables = [
      SMTVariableDeclaration(name: "x", sort: .int)
    ]

    let pathCondition = PathCondition(conditions: conditions, variables: variables)

    #expect(pathCondition.conditions.count == 2)
    #expect(pathCondition.variables.count == 1)
  }

  // MARK: - SMTSolverError Tests

  @Test("SMTSolverError cases exist")
  func testSolverErrorCases() {
    let timeout = SMTSolverError.timeout
    let solverError = SMTSolverError.solverError("test")
    let invalidInput = SMTSolverError.invalidInput("invalid")
    let unsupported = SMTSolverError.unsupportedOperation("op")

    // Verify they are distinct error cases via pattern matching
    if case .timeout = timeout {} else { Issue.record("Expected timeout") }
    if case .solverError = solverError {} else { Issue.record("Expected solverError") }
    if case .invalidInput = invalidInput {} else { Issue.record("Expected invalidInput") }
    if case .unsupportedOperation = unsupported {
    } else {
      Issue.record("Expected unsupportedOperation")
    }
  }

  // MARK: - SMTSolverStatistics Tests

  @Test("SMTSolverStatistics stores values")
  func testSolverStatistics() {
    let stats = SMTSolverStatistics(
      solveCount: 5,
      solverPath: "z3",
      timeout: .seconds(30)
    )

    #expect(stats.solveCount == 5)
    #expect(stats.solverPath == "z3")
  }

  // MARK: - SMTExamples Tests

  @Test("SMTExamples prime number constraints builds correctly")
  func testPrimeNumberConstraints() {
    let generator = SMTExamples.primeNumberConstraints()
    // Just verify it can be created without crashing
    _ = generator.constraintBuilder
  }

  @Test("SMTExamples pythagorean triple constraints builds correctly")
  func testPythagoreanTripleConstraints() {
    let generator = SMTExamples.pythagoreanTripleConstraints()
    // Just verify it can be created without crashing
    _ = generator.constraintBuilder
  }

  // MARK: - Complex Expression Building

  @Test("Complex nested expression builds correctly")
  func testComplexExpressionBuilding() {
    // Build: (x > 0) AND (x < 100) AND (x mod 2 = 0)
    let x = SMTExpression.variable("x")
    let zero = SMTExpression.constant(.int(0))
    let hundred = SMTExpression.constant(.int(100))
    let two = SMTExpression.constant(.int(2))

    let positive = SMTExpression.binary(.greaterThan, x, zero)
    let bounded = SMTExpression.binary(.lessThan, x, hundred)
    let even = SMTExpression.binary(.equals, .binary(.modulo, x, two), zero)

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
