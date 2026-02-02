import XCTest
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import InvariantCore
@testable import InvariantSwiftMacros

final class BusinessRuleMacroTests: XCTestCase {

  let testMacros: [String: Macro.Type] = [
    "BusinessRule": BusinessRuleMacro.self
  ]

  func testBasicBusinessRuleExpansion() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Age must be at least 18")
      func validateAge(age: Int) -> Bool {
          return age >= 18
      }
      """,
      expandedSource: """
        func validateAge(age: Int) -> Bool {
            return age >= 18
        }

        @Test("Age must be at least 18")
        func validateAge_PropertyTest() async throws {
            let property = Property<Int>(generator: Gen<Int>.age, predicate: { value in
                    validateAge(age: value)
                })
            let config = PropertyConfig(iterations: PropertyConfig.smartIterations, maxShrinks: 1000, maxDiscarded: 1000, seed: nil)
            let runner = PropertyRunner()
            let result = await runner.runProperty(property, config: config)
            switch result {
            case .success:
                break

            case .failure(counterexample: let counterexample, iterations: let iterations, shrunk: let shrunk, _: _, _: _):
                throw BusinessRuleViolation(rule: "Age must be at least 18", counterexample: String(describing: counterexample), shrunk: String(describing: shrunk), iterations: iterations, businessImpact: "Business rule validation failed - this may indicate a logical error in business constraints")

            case .gaveUp(discarded: let discarded, iterations: let iterations):
                throw BusinessRuleGaveUp(rule: "Age must be at least 18", discarded: discarded, iterations: iterations, suggestion: "Consider relaxing generator constraints or providing more specific generators")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testMultipleParametersBusinessRule() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Discount cannot exceed price")
      func validateDiscount(price: Double, discount: Double) -> Bool {
          return discount <= price
      }
      """,
      expandedSource: """
        func validateDiscount(price: Double, discount: Double) -> Bool {
            return discount <= price
        }

        @Test("Discount cannot exceed price")
        func validateDiscount_PropertyTest() async throws {
            let property = Property<(Double, Double)>(generator: Gen.zip(Gen<Decimal>.currency, Gen<Double>.double), predicate: { value in
                    validateDiscount(price: value.0, discount: value.1)
                })
            let config = PropertyConfig(iterations: PropertyConfig.smartIterations, maxShrinks: 1000, maxDiscarded: 1000, seed: nil)
            let runner = PropertyRunner()
            let result = await runner.runProperty(property, config: config)
            switch result {
            case .success:
                break

            case .failure(counterexample: let counterexample, iterations: let iterations, shrunk: let shrunk, _: _, _: _):
                throw BusinessRuleViolation(rule: "Discount cannot exceed price", counterexample: String(describing: counterexample), shrunk: String(describing: shrunk), iterations: iterations, businessImpact: "Business rule validation failed - this may indicate a logical error in business constraints")

            case .gaveUp(discarded: let discarded, iterations: let iterations):
                throw BusinessRuleGaveUp(rule: "Discount cannot exceed price", discarded: discarded, iterations: iterations, suggestion: "Consider relaxing generator constraints or providing more specific generators")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testCustomIterationsBusinessRule() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Amount must be positive", iterations: 500)
      func validateAmount(amount: Double) -> Bool {
          return amount > 0
      }
      """,
      expandedSource: """
        func validateAmount(amount: Double) -> Bool {
            return amount > 0
        }

        @Test("Amount must be positive")
        func validateAmount_PropertyTest() async throws {
            let property = Property<Double>(generator: Gen<Decimal>.currency, predicate: { value in
                    validateAmount(amount: value)
                })
            let config = PropertyConfig(iterations: 500, maxShrinks: 1000, maxDiscarded: 1000, seed: nil)
            let runner = PropertyRunner()
            let result = await runner.runProperty(property, config: config)
            switch result {
            case .success:
                break

            case .failure(counterexample: let counterexample, iterations: let iterations, shrunk: let shrunk, _: _, _: _):
                throw BusinessRuleViolation(rule: "Amount must be positive", counterexample: String(describing: counterexample), shrunk: String(describing: shrunk), iterations: iterations, businessImpact: "Business rule validation failed - this may indicate a logical error in business constraints")

            case .gaveUp(discarded: let discarded, iterations: let iterations):
                throw BusinessRuleGaveUp(rule: "Amount must be positive", discarded: discarded, iterations: iterations, suggestion: "Consider relaxing generator constraints or providing more specific generators")
            }
        }
        """,
      macros: testMacros
    )
  }

  func testBusinessRuleOnlyAppliesToFunctions() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Test rule")
      struct TestStruct {
          let value: Int
      }
      """,
      expandedSource: """
        struct TestStruct {
            let value: Int
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@BusinessRule can only be applied to functions",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testBusinessRuleRequiresBoolReturnType() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Test rule")
      func testFunction(value: Int) -> Int {
          return value * 2
      }
      """,
      expandedSource: """
        func testFunction(value: Int) -> Int {
            return value * 2
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@BusinessRule functions must return Bool",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testBusinessRuleRequiresParameters() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Test rule")
      func testFunction() -> Bool {
          return true
      }
      """,
      expandedSource: """
        func testFunction() -> Bool {
            return true
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@BusinessRule requires at least one parameter to generate test values",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testSmartGeneratorInferenceForEmail() throws {
    assertMacroExpansion(
      """
      @BusinessRule("Email must be valid format")
      func validateEmail(email: String) -> Bool {
          return email.contains("@")
      }
      """,
      expandedSource: """
        func validateEmail(email: String) -> Bool {
            return email.contains("@")
        }

        @Test("Email must be valid format")
        func validateEmail_PropertyTest() async throws {
            let property = Property<String>(generator: Gen<String>.email, predicate: { value in
                    validateEmail(email: value)
                })
            let config = PropertyConfig(iterations: PropertyConfig.smartIterations, maxShrinks: 1000, maxDiscarded: 1000, seed: nil)
            let runner = PropertyRunner()
            let result = await runner.runProperty(property, config: config)
            switch result {
            case .success:
                break

            case .failure(counterexample: let counterexample, iterations: let iterations, shrunk: let shrunk, _: _, _: _):
                throw BusinessRuleViolation(rule: "Email must be valid format", counterexample: String(describing: counterexample), shrunk: String(describing: shrunk), iterations: iterations, businessImpact: "Business rule validation failed - this may indicate a logical error in business constraints")

            case .gaveUp(discarded: let discarded, iterations: let iterations):
                throw BusinessRuleGaveUp(rule: "Email must be valid format", discarded: discarded, iterations: iterations, suggestion: "Consider relaxing generator constraints or providing more specific generators")
            }
        }
        """,
      macros: testMacros
    )
  }

  // MARK: - Diagnostic Tests for New Cases

  func testBusinessRuleRequiresDescription() throws {
    assertMacroExpansion(
      """
      @BusinessRule
      func testFunction(value: Int) -> Bool {
          return value > 0
      }
      """,
      expandedSource: """
        func testFunction(value: Int) -> Bool {
            return value > 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@BusinessRule requires a description string as the first argument",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }

  func testBusinessRuleRequiresStringDescription() throws {
    assertMacroExpansion(
      """
      @BusinessRule(123)
      func testFunction(value: Int) -> Bool {
          return value > 0
      }
      """,
      expandedSource: """
        func testFunction(value: Int) -> Bool {
            return value > 0
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          message: "@BusinessRule description must be a string literal",
          line: 1,
          column: 1
        )
      ],
      macros: testMacros
    )
  }
}
