/// **Business-Friendly Property Testing Macros**
///
/// This module provides macro declarations that transform complex property-based testing
/// concepts into accessible business-friendly APIs. These macros bridge the gap between
/// mathematical property testing and practical business validation needs.
///
/// **Mathematical Foundation:**
/// Built on category theory principles with property-based testing theory,
/// these macros hide mathematical complexity behind intuitive business interfaces
/// while maintaining theoretical rigor and correctness guarantees.
///
/// **Core Business Macros:**
/// - **@BusinessRule**: Transform business rules into property-based tests
/// - **@SmartGenerator**: Automatic test data generation from type structure
/// - **@TestAllCases**: Systematic boundary and edge case testing
///
/// **Integration:** These macros integrate seamlessly with existing FunctionalTesting
/// infrastructure including Property<T>, Gen<T>, PropertyRunner, and Swift Testing framework.
///
/// **External References:**
/// - [Swift Macros Guide](https://docs.swift.org/swift-book/LanguageGuide/Macros.html)
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)

import Foundation

// MARK: - @BusinessRule Macro

/// **Transform business rules into comprehensive property-based tests**
///
/// The @BusinessRule macro converts business validation functions into property-based tests
/// with intelligent iteration calculation, business-friendly error reporting, and automatic
/// generator synthesis. This macro is designed for business stakeholders and developers
/// who need robust validation without deep property testing expertise.
///
/// **Mathematical Foundation:**
/// Based on property-based testing theory where ∀ x ∈ Domain, P(x) = true.
/// Uses counterexample-guided abstraction refinement (CEGAR) for minimal
/// counterexample discovery and business-friendly error interpretation.
///
/// **Key Features:**
/// - **Smart Iteration Calculation**: Automatically determines optimal test coverage based on complexity analysis
/// - **Business Error Reporting**: Transforms mathematical counterexamples into actionable business insights
/// - **Generator Synthesis**: Automatically creates appropriate generators based on parameter names and types
/// - **Swift Testing Integration**: Generates @Test compatible functions for seamless framework integration
/// - **Risk-Aware Testing**: Applies higher scrutiny to financial and business-critical operations
///
/// **Usage Examples:**
/// ```swift
/// import FunctionalTesting
/// import Testing
///
/// @BusinessRule("Customer discount should not exceed item price")
/// func validateDiscount(item: Item, discount: Discount) -> Bool {
///     return discount.amount <= item.price
/// }
///
/// @BusinessRule("Order total equals sum of item prices", iterations: .fixed(500))
/// func validateOrderTotal(order: Order) -> Bool {
///     let calculatedTotal = order.items.map(\.price).reduce(0, +)
///     return abs(order.total - calculatedTotal) < 0.01
/// }
///
/// @BusinessRule("Email addresses must be valid format", iterations: .adaptive(min: 50, max: 200))
/// func validateEmailFormat(email: String) -> Bool {
///     return email.contains("@") && email.contains(".")
/// }
/// ```
///
/// **Generated Test Structure:**
/// ```swift
/// // Generated for the discount example above:
/// @Test("Customer discount should not exceed item price")
/// func validateDiscount_PropertyTest() async throws {
///     let property = Property<(Item, Discount)>(
///         generator: Item.smartGen.zip(Discount.smartGen),
///         predicate: { tuple in
///             validateDiscount(item: tuple.0, discount: tuple.1)
///         }
///     )
///
///     let result = await PropertyRunner().runProperty(property, config: smartConfig)
///
///     // Business-friendly error reporting on failure
///     if case .failure(let counterexample, let iterations, let shrunk) = result {
///         throw BusinessRuleViolation(
///             rule: "Customer discount should not exceed item price",
///             counterexample: AnySendable(counterexample),
///             shrunk: AnySendable(shrunk),
///             businessImpact: "Financial discrepancies that may impact business operations...",
///             remediation: ["Review discount calculation logic...", "Add validation..."],
///             iterations: iterations,
///             severity: .critical
///         )
///     }
/// }
/// ```
///
/// **Parameters:**
/// - **description**: Human-readable business rule description (required)
/// - **iterations**: Testing strategy - .smart (recommended), .fixed(count), or .adaptive(min:max:)
/// - **timeout**: Maximum test execution time in seconds (default: 30.0)
///
/// **Business Impact Analysis:**
/// The macro automatically analyzes parameter names for business context:
/// - **Financial Terms**: price, amount, currency, rate → Critical severity, enhanced testing
/// - **Customer Data**: email, name, address → High severity, privacy considerations
/// - **General Business**: order, product, user → Medium severity, standard validation
///
/// **Complexity-Driven Testing:**
/// Iteration counts are automatically calculated based on:
/// - Parameter count and types
/// - Business domain risk factors (financial = 1.5x multiplier)
/// - Parameter name semantic analysis
/// - Function complexity heuristics
///
/// **Integration Requirements:**
/// - Function must return Bool (business rule validation result)
/// - Parameters should have appropriate generators (built-in or SmartGeneratable)
/// - Access to FunctionalTesting infrastructure (Property, Gen, PropertyRunner)
/// - Swift Testing framework for @Test attribute compatibility
///
/// **Error Scenarios:**
/// - **Rule Violation**: Throws BusinessRuleViolation with actionable remediation
/// - **Generation Failure**: Reports data generation issues with suggested fixes
/// - **Timeout**: Reports performance issues with optimization suggestions
///
/// **Performance Characteristics:**
/// - **Small Functions** (1-2 params): 50-200 iterations, <1 second execution
/// - **Medium Functions** (3-4 params): 200-800 iterations, 1-5 second execution
/// - **Complex Functions** (5+ params): 800-2000 iterations, 5-30 second execution
/// - **Financial Functions**: 1.5x iteration multiplier for enhanced validation
///
/// **External References:**
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
/// - [QuickCheck Original Paper](https://dl.acm.org/doi/10.1145/351240.351266)
/// - [Counterexample-Guided Abstraction Refinement](https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement)
/// - [Business Rules in Software](https://en.wikipedia.org/wiki/Business_rule)
@attached(peer, names: suffixed(_PropertyTest))
public macro BusinessRule(
  _ description: String,
  iterations: BusinessRuleIterations = .smart,
  timeout: TimeInterval = 30.0
) = #externalMacro(module: "FunctionalTestingMacros", type: "BusinessRuleMacro")

// MARK: - @SmartGenerator Macro (Future Implementation)

/// **Automatic test data generation from type structure**
///
/// The @SmartGenerator macro analyzes type definitions to automatically derive
/// appropriate generators based on property names, types, and business domain conventions.
/// This eliminates the need for manual generator implementation in most cases.
///
/// **Note:** This macro is part of Phase 1 planning but not yet implemented.
/// The declaration is provided for future compatibility.
///
/// **Planned Usage:**
/// ```swift
/// @SmartGenerator
/// struct User {
///     let id: UUID
///     let name: String        // → Gen.personName
///     let email: String       // → Gen.email
///     let age: Int            // → Gen.age
///     let balance: Decimal    // → Gen.currency
/// }
///
/// // Automatically generates:
/// extension User: SmartGeneratable {
///     static var smartGen: Gen<User> {
///         Gen.zip4(Gen.uuid, Gen.personName, Gen.email, Gen.age, Gen.currency)
///             .map(User.init)
///     }
/// }
/// ```
@attached(member, names: named(smartGen))
// @attached(extension, conformances: SmartGeneratable)  // TODO: Define SmartGeneratable protocol
public macro
  SmartGenerator(  // constraints: GeneratorConstraints = .realistic  // TODO: Define GeneratorConstraints
  ) = #externalMacro(module: "FunctionalTestingMacros", type: "SmartGeneratorMacro")

// MARK: - @TestAllCases Macro (Future Implementation)

/// **Systematic boundary and edge case testing**
///
/// The @TestAllCases macro generates comprehensive test suites that systematically
/// explore boundary conditions, edge cases, and equivalence partitions without
/// requiring deep testing expertise from developers.
///
/// **Note:** This macro is part of Phase 1 planning but not yet implemented.
/// The declaration is provided for future compatibility.
///
/// **Planned Usage:**
/// ```swift
/// @TestAllCases(focus: .comprehensive)
/// enum OrderStatus {
///     case pending, confirmed, processing, shipped, delivered, cancelled
/// }
///
/// // Automatically generates boundary and transition tests
/// ```
@attached(member, names: arbitrary)
// @attached(extension, conformances: AutoTestable)  // TODO: Define AutoTestable protocol
public macro TestAllCases(
  focus: TestFocus = .comprehensive
) = #externalMacro(module: "FunctionalTestingMacros", type: "TestAllCasesMacro")

// MARK: - Supporting Types

/// **Test focus for comprehensive testing strategies**
///
/// Controls the scope and intensity of automatic test case generation for @TestAllCases macro.
/// Different focus levels provide different trade-offs between coverage and execution time.
public enum TestFocus: Sendable {
  /// **Comprehensive testing** - Maximum coverage including edge cases, boundaries, and equivalence partitions
  case comprehensive

  /// **Boundary focus** - Concentrates on boundary value analysis and limit conditions
  case boundary

  /// **Edge cases only** - Minimal testing focusing on known problematic values
  case edges
}
