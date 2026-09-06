/// SMTSolverTests - Comprehensive tests for SMT solver integration
///
/// Verifies SMTExpression, SMTConstraint, SMTSolver, SMTGenerator,
/// and PathCondition functionality.

import Testing
import Foundation
@testable import InvariantSwift
@testable import InvariantSwiftAdvanced

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

}

@Suite("SMT Solver and Configuration")
struct SMTSolverConfigurationTests {
  @Test("SMTSolverConfig has correct defaults")
  func testSolverConfigDefaults() {
    let config = SMTSolverConfig()
    #expect(config.solverPath == "z3")
    #expect(config.memoryLimit == nil)
    #expect(config.randomSeed == nil)
  }

  @Test("SMTSolverConfig static configs exist")
  func testSolverConfigStatics() {
    let zThreeConfig = SMTSolverConfig.zThree
    #expect(zThreeConfig.solverPath == "z3")

    let cvc4Config = SMTSolverConfig.cvc4
    #expect(cvc4Config.solverPath == "cvc4")
  }

  // MARK: - SMTSolver Tests

  @Test("SMTSolver initializes with config")
  func testSolverInitialization() async {
    let solver = SMTSolver(config: .zThree)
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

  @Test("SMTResult success cases exist")
  func testResultSuccessCases() {
    guard case .satisfiable = SMTResult.satisfiable([:]) else {
      Issue.record("Expected satisfiable")
      return
    }
    guard case .unsatisfiable = SMTResult.unsatisfiable else {
      Issue.record("Expected unsatisfiable")
      return
    }
  }

  @Test("SMTResult indeterminate cases exist")
  func testResultIndeterminateCases() {
    guard case .unknown = SMTResult.unknown else {
      Issue.record("Expected unknown")
      return
    }
    guard case .timeout = SMTResult.timeout else {
      Issue.record("Expected timeout")
      return
    }
    guard case .error = SMTResult.error("test error") else {
      Issue.record("Expected error")
      return
    }
  }

}

@Suite("SMT Path Conditions and Examples")
struct SMTPathConditionTests {
  @Test("PathCondition stores conditions and variables")
  func testPathConditionStorage() {
    let conditions: [SMTExpression] = [
      .binary(.greaterThan, .variable("x"), .constant(.int(0))),
      .binary(.lessThan, .variable("x"), .constant(.int(100))),
    ]

    let variables = [
      SMTVariableDeclaration(name: "x", sort: .int)
    ]

    let pathCondition = PathCondition(
      conditions: conditions,
      variables: variables
    )

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

    guard case .timeout = timeout else {
      Issue.record("Expected timeout")
      return
    }
    guard case .solverError = solverError else {
      Issue.record("Expected solverError")
      return
    }
    guard case .invalidInput = invalidInput else {
      Issue.record("Expected invalidInput")
      return
    }
    guard case .unsupportedOperation = unsupported else {
      Issue.record("Expected unsupportedOperation")
      return
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
}
