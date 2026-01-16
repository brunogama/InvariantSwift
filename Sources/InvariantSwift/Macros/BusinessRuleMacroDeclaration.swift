import Foundation

// MARK: - @BusinessRule Macro Declaration

/// **@BusinessRule - Transform business logic functions into property-based tests**
///
/// This macro revolutionizes business rule testing by automatically generating comprehensive
/// property-based tests from simple boolean functions. It hides mathematical complexity
/// behind business-friendly APIs while providing enterprise-grade test coverage.
///
/// **Core Benefits:**
/// - **Zero Learning Curve**: Write business rules as simple boolean functions
/// - **Automatic Test Generation**: Macro creates comprehensive property-based tests
/// - **Business-Friendly Errors**: Clear, actionable error messages for stakeholders
/// - **Enterprise Integration**: Seamless Swift Testing compatibility
/// - **Mathematical Rigor**: Hidden property-based testing ensures thorough coverage
///
/// **Usage Example:**
/// ```swift
/// @BusinessRule("Customer age must be at least 18 for premium accounts")
/// func validatePremiumAge(customer: Customer, account: Account) -> Bool {
///     guard account.isPremium else { return true }
///     return customer.age >= 18
/// }
///
/// @BusinessRule("Order total must equal sum of line items", iterations: 500)
/// func validateOrderTotal(order: Order) -> Bool {
///     let lineItemsTotal = order.lineItems.map(\.amount).reduce(0, +)
///     return abs(order.total - lineItemsTotal) < 0.01
/// }
///
/// @BusinessRule("Discount percentage must be between 0 and 100")
/// func validateDiscountRange(discount: Discount) -> Bool {
///     return discount.percentage >= 0 && discount.percentage <= 100
/// }
/// ```
///
/// **Generated Tests:**
/// The macro automatically generates `@Test` functions that:
/// 1. **Smart Generator Inference**: Automatically creates appropriate test data generators
/// 2. **Property-Based Testing**: Systematically explores edge cases and boundary conditions
/// 3. **Intelligent Shrinking**: Finds minimal failing examples for easier debugging
/// 4. **Business Error Reporting**: Provides clear error messages with business context
/// 5. **Performance Optimization**: Uses smart iteration counts based on complexity
///
/// **Smart Generator Inference:**
/// The macro intelligently chooses generators based on parameter names and types:
/// ```swift
/// // Parameter name inference:
/// email: String      → Gen.email          // Generates realistic email addresses
/// age: Int          → Gen.age             // Generates realistic age ranges
/// price: Decimal    → Gen.currency        // Generates monetary amounts
/// name: String      → Gen.firstName       // Generates common first names
/// id: String        → Gen.uuid            // Generates unique identifiers
///
/// // Type-based fallbacks:
/// String            → Gen.string          // General string generation
/// Int               → Gen.int             // Integer generation with edge cases
/// Bool              → Gen.bool            // Boolean generation
/// [T]               → Gen.array(T.gen)    // Array generation
/// CustomType        → CustomType.smartGen // Uses @SmartGenerator if available
/// ```
///
/// **Configuration Options:**
/// - `iterations`: Number of test cases (default: `.smart` for automatic calculation)
/// - `timeout`: Maximum test execution time (default: 30 seconds)
///
/// **Mathematical Foundation (Hidden from Users):**
/// While business users see simple boolean functions, the implementation leverages:
/// - **Universal Quantification**: ∀ x ∈ Domain, P(x) = true
/// - **Random Testing Theory**: Statistical confidence through systematic exploration
/// - **Shrinking Algorithms**: Tree-based search for minimal counterexamples
/// - **Generator Composition**: Functor/Applicative laws for complex data structures
/// - **Coverage Analysis**: Ensures comprehensive exploration of input space
///
/// **Error Reporting:**
/// When business rules fail, you get actionable error messages:
/// ```
/// ❌ Business Rule Violation
///
/// Rule: Customer age must be at least 18 for premium accounts
///
/// 🔍 Analysis:
/// • Failed after 47 test iterations
/// • Original failing input: Customer(age: 16, name: "John")
/// • Minimal failing input: Customer(age: 0, name: "")
///
/// 💼 Business Impact:
/// Underage customers may be granted premium access, violating regulatory requirements
///
/// 🛠 Next Steps:
/// 1. Review the business logic in the failing function
/// 2. Verify the minimal failing input makes business sense
/// 3. Update business constraints or fix the implementation
/// ```
///
/// **Performance Characteristics:**
/// - **Smart Iterations**: Automatically calculates optimal test count
/// - **Fast Feedback**: Development mode uses fewer iterations for speed
/// - **Production Ready**: Critical mode provides exhaustive testing
/// - **Parallelizable**: Tests can run concurrently for better CI performance
///
/// **Integration with Existing Infrastructure:**
/// The macro leverages and extends the FunctionalTesting framework:
/// - Uses existing `Property<T>` and `Gen<T>` infrastructure
/// - Integrates with `PropertyRunner` for async execution
/// - Compatible with Swift Testing `@Test` functions
/// - Supports existing generator combinators and shrinking
/// - Extends generator library with business domain types
///
/// **External References:**
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Software_testing#Property_testing)
/// - [QuickCheck: A Lightweight Tool for Random Testing](https://dl.acm.org/doi/10.1145/351240.351266)
/// - [Finding and Understanding Bugs in C Compilers](https://dl.acm.org/doi/10.1145/1993498.1993532)
/// - [Test-Case Reduction via Test-Case Generation](https://dl.acm.org/doi/10.1145/2362389.2362422)
@attached(peer, names: suffixed(_PropertyTest))
public macro BusinessRule(
  _ description: String,
  iterations: Int = .smart,
  timeout: TimeInterval = 30.0
) = #externalMacro(module: "InvariantSwiftMacros", type: "BusinessRuleMacro")

// MARK: - Smart Iteration Configuration

extension Int {
  /// **Smart iteration count that automatically adapts to complexity**
  ///
  /// Provides intelligent test coverage based on:
  /// - Parameter count and complexity
  /// - Type complexity (custom types vs primitives)
  /// - Historical failure patterns
  /// - Performance constraints
  ///
  /// **Theory Behind Smart Iterations:**
  /// Based on statistical testing theory and coverage probability:
  /// - Simple rules: 100-200 iterations provide 99%+ confidence
  /// - Complex rules: 300-500 iterations for comprehensive coverage
  /// - Critical rules: 1000+ iterations for maximum confidence
  ///
  /// The smart algorithm analyzes the function signature and automatically
  /// selects appropriate iteration counts for optimal coverage/performance balance.
  public static let smart: Int = -1  // Special marker for smart calculation
}
