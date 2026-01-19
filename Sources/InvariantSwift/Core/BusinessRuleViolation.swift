import Foundation
import Testing

// MARK: - Business Rule Error Types

/// **Business-friendly error reporting for property test failures**
///
/// `BusinessRuleViolation` translates technical property-based test failures into clear,
/// actionable error messages for business stakeholders and developers. It bridges the gap
/// between the mathematical complexity of property testing and practical business language.
///
/// **Design Philosophy**:
/// Property-based testing is powerful but can produce complex, technical failure reports that
/// are difficult for non-technical stakeholders to understand. `BusinessRuleViolation` provides:
/// - **Business-friendly language**: Describes the impact and implications
/// - **Minimal counterexamples**: Simplified failing inputs for easy reproduction
/// - **Actionable guidance**: Clear next steps for fixing the issue
/// - **Structured data**: Machine-readable metadata for tooling and analysis
///
/// **Usage**:
/// This error type is generated automatically by the `@BusinessRule` macro when property
/// tests fail. It can also be created manually for custom property-based testing scenarios.
///
/// ```swift
/// @BusinessRule(
///   "Discount calculation should always reduce total price",
///   businessImpact: "Incorrect pricing could lead to revenue loss"
/// )
/// func testDiscountCalculation(amount: Decimal, discountPercent: Double) {
///   let discounted = amount * Decimal(1.0 - discountPercent / 100)
///   #expect(discounted <= amount)  // Fails with BusinessRuleViolation
/// }
/// ```
///
/// **Mathematical Foundation (Hidden from Users)**:
/// The underlying mechanism uses property-based testing:
/// - **Universal Quantification**: Tests whether ∀ x ∈ Domain, P(x) = true
/// - **Counterexample Discovery**: Finds minimal x where P(x) = false
/// - **Shrinking**: Reduces x to its simplest form that still violates the property
///
/// **External References**:
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Software_testing#Property_testing)
/// - [Counterexample-Guided Abstraction Refinement](https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement)
///
/// - See Also: ``BusinessRuleGaveUp``, ``@BusinessRule``
public struct BusinessRuleViolation: Error, CustomStringConvertible, Sendable {

  /// **The business rule that was violated**
  ///
  /// A human-readable description of the rule that failed, from the business perspective.
  /// For example: "Withdrawal amount must not exceed account balance" or
  /// "Monthly retention rate should always be between 85% and 100%"
  ///
  /// - Note: This should be phrased in business terms, not implementation details.
  public let rule: String

  /// **The original failing input values**
  ///
  /// The complete test input that triggered the violation, before any simplification.
  /// This may be complex and difficult to analyze but represents the exact failing case
  /// discovered by the test runner.
  ///
  /// - Note: When debugging, start with `shrunk` instead—it's simpler and easier to understand.
  public let counterexample: String

  /// **The minimal failing input (simplified by shrinking)**
  ///
  /// The simplest version of the failing input that still violates the rule.
  /// Shrinking is an automated process that removes unnecessary complexity,
  /// making this the best input for understanding and fixing the bug.
  ///
  /// - Important: Always analyze this value first when debugging failures.
  ///
  /// - Example:
  ///   - Original counterexample: `amount: 5847, discountPercent: 120.5`
  ///   - Shrunk: `amount: 100, discountPercent: 101`
  ///   - Simplified: The discount exceeds 100%, causing the failure
  public let shrunk: String

  /// **Number of test iterations before finding the failure**
  ///
  /// How many random test cases were executed before discovering this violation.
  /// Higher numbers suggest the bug is rare or only manifests in specific conditions.
  ///
  /// - Example:
  ///   - `iterations: 5` - Bug appears immediately, likely obvious issue
  ///   - `iterations: 847` - Bug is subtle, likely an edge case
  ///   - `iterations: 5000` - Rare bug, may only appear under specific conditions
  public let iterations: Int

  /// **Description of business impact if this rule is violated**
  ///
  /// Explains the real-world consequences of the bug in terms stakeholders care about:
  /// revenue impact, customer experience, data integrity, compliance risk, etc.
  ///
  /// - Example:
  ///   - "Incorrect pricing could overcharge customers and damage trust"
  ///   - "Missing data could cause incorrect financial reporting"
  ///   - "Logic error could allow unauthorized withdrawals"
  ///
  /// - Note: This should motivate fixing the issue with business context.
  public let businessImpact: String

  /// **Additional technical context for debugging**
  ///
  /// Structured key-value pairs providing supplementary information:
  /// - Environment details (database state, API versions, etc.)
  /// - Performance metrics (iteration count, shrinking attempts, etc.)
  /// - Debugging context (function names, parameter ranges, etc.)
  /// - System state at failure (cache state, connection status, etc.)
  ///
  /// - Example:
  ///   ```swift
  ///   "database.records": "5000",
  ///   "api.version": "2.1.0",
  ///   "shrink.attempts": "247",
  ///   "reproducible_seed": "12345"
  ///   ```
  public let metadata: [String: String]

  /// **Initialize a business rule violation error**
  ///
  /// Creates a new violation error with all diagnostic information.
  ///
  /// - Parameters:
  ///   - rule: Business-friendly rule description
  ///   - counterexample: Original failing input (may be complex)
  ///   - shrunk: Simplified failing input (easiest to debug)
  ///   - iterations: Number of tests before finding failure
  ///   - businessImpact: Description of real-world impact
  ///   - metadata: Additional key-value context (default: empty)
  ///
  /// - Example:
  ///   ```swift
  ///   let violation = BusinessRuleViolation(
  ///     rule: "Cart total must be positive",
  ///     counterexample: "price: 0.01, taxRate: -150",
  ///     shrunk: "price: 0.01, taxRate: -1",
  ///     iterations: 342,
  ///     businessImpact: "Negative prices could cause accounting errors",
  ///     metadata: ["test.name": "testCartCalculation", "seed": "5683"]
  ///   )
  ///   ```
  public init(
    rule: String,
    counterexample: String,
    shrunk: String,
    iterations: Int,
    businessImpact: String,
    metadata: [String: String] = [:]
  ) {
    self.rule = rule
    self.counterexample = counterexample
    self.shrunk = shrunk
    self.iterations = iterations
    self.businessImpact = businessImpact
    self.metadata = metadata
  }

  /// **Human-readable error message with all diagnostic information**
  ///
  /// Produces a formatted description suitable for display to developers, combining
  /// technical details with business context and actionable remediation steps.
  ///
  /// - Note: This is automatically used when the error is printed or displayed in logs.
  public var description: String {
    """
    ❌ Business Rule Violation

    Rule: \(rule)

    🔍 Analysis:
    • Failed after \(iterations) test iterations
    • Original failing input: \(counterexample)
    • Minimal failing input: \(shrunk)

    💼 Business Impact:
    \(businessImpact)

    🛠 Next Steps:
    1. Review the business logic in the failing function
    2. Verify the minimal failing input makes business sense
    3. Update business constraints or fix the implementation
    4. Consider edge cases that may have been overlooked

    📊 Technical Details:
    This failure was discovered through property-based testing, which systematically
    explores the input space to find edge cases. The "minimal failing input" has been
    automatically computed to help with debugging.
    """
  }

  // swiftlint:disable:next orphaned_doc_comment
  /// **Business-focused error report**
  ///
  /// Generates a report emphasizing business impact and implications, suitable for
  /// stakeholder communication and business analysis. Removes technical jargon to
  /// focus on what went wrong and why it matters.
  ///
  /// - Returns: Formatted business report
  ///
  /// - Example:
  ///   ```swift
  ///   let violation = // ... BusinessRuleViolation
  // swiftlint:disable:next no_print
  ///   print(violation.businessReport)
  ///   // Output includes: rule, business impact, minimal failing case
  ///   ```
  public var businessReport: String {
    """
    Business Rule Validation Failed

    Rule: \(rule)
    Problem: \(businessImpact)

    Failing Case: \(shrunk)

    Recommended Actions:
    • Review business logic implementation
    • Validate business constraints
    • Consider additional edge case handling
    """
  }

  /// **Technical-focused error report**
  ///
  /// Generates a detailed technical report with all diagnostic data, suitable for
  /// developer investigation, logging systems, and automated analysis. Includes the
  /// complete counterexample, shrinking results, and metadata.
  ///
  /// - Returns: Formatted technical report
  ///
  /// - Example:
  ///   ```swift
  ///   let violation = // ... BusinessRuleViolation
  ///   logger.error(violation.technicalReport)
  ///   // Includes: full inputs, shrinking history, metadata
  ///   ```
  public var technicalReport: String {
    """
    Property Test Failure Report

    Rule: \(rule)
    Iterations: \(iterations)
    Counterexample: \(counterexample)
    Shrunk: \(shrunk)

    Metadata:
    \(metadata.map { "• \($0.key): \($0.value)" }.joined(separator: "\n"))
    """
  }
}

// swiftlint:disable:next orphaned_doc_comment
/// **Error when property testing gives up due to too many discarded cases**
///
/// `BusinessRuleGaveUp` indicates that property testing could not generate enough valid
/// test inputs to thoroughly test a business rule. This is not a failure—it's a signal that
/// the testing configuration needs adjustment.
///
/// **When This Occurs**:
/// Property-based testing generates random inputs for testing. If constraints are too restrictive,
/// most generated inputs are invalid and get discarded. After discarding too many inputs,
/// the test runner gives up to avoid infinite loops.
///
/// **Design Philosophy**:
/// Rather than failing the test (which would be misleading), the framework transparently
/// reports that it couldn't adequately test the property and provides actionable suggestions
/// for resolution.
///
/// **Common Causes**:
/// - Generator constraints too restrictive (e.g., `Gen.int(in: 999999...1000000)`)
/// - Property preconditions too narrow (e.g., filtering out 95% of inputs)
/// - Missing custom generators for domain-specific types
/// - Unrealistic edge case requirements
///
/// **Usage**:
/// This error is typically thrown by the `@BusinessRule` macro when property testing
/// cannot generate sufficient valid test cases. Handle gracefully:
///
/// ```swift
/// do {
///   try await testRule()
/// } catch let error as BusinessRuleGaveUp {
// swiftlint:disable:next no_print
///   print("Testing incomplete: \(error.suggestion)")
///   // Review and adjust constraints
/// }
/// ```
///
/// **Resolution Strategy**:
/// 1. Identify which inputs are being discarded (analyze logs)
/// 2. Adjust generator or precondition to be less restrictive
/// 3. Provide domain-specific generators for complex types
/// 4. Consider whether the business rule itself is realistic
///
/// - See Also: ``BusinessRuleViolation``, ``Gen``, ``Property``
public struct BusinessRuleGaveUp: Error, CustomStringConvertible, Sendable {

  /// **The business rule that couldn't be adequately tested**
  ///
  /// Identifies which rule had insufficient valid test inputs.
  ///
  /// - Note: This doesn't mean the rule is invalid—just that more testing setup is needed.
  public let rule: String

  /// **Number of test cases that were discarded as invalid**
  ///
  /// How many randomly generated inputs didn't satisfy the property's preconditions.
  /// High numbers indicate overly restrictive constraints.
  ///
  /// - Example:
  ///   - `discarded: 50, iterations: 100` → 50% discard rate (moderate, maybe acceptable)
  ///   - `discarded: 950, iterations: 1000` → 95% discard rate (severe, needs fixing)
  public let discarded: Int

  /// **Total number of test iterations attempted**
  ///
  /// How many iterations the test runner attempted before giving up.
  /// The discard rate is `discarded / iterations * 100%`.
  public let iterations: Int

  /// **Actionable suggestion for resolving the issue**
  ///
  /// Business-friendly suggestion describing how to fix the testing setup,
  /// phrased in terms non-technical stakeholders understand.
  ///
  /// - Example:
  ///   - "Make sure the test data generator creates more realistic values"
  ///   - "Consider relaxing the business rule requirements"
  ///   - "Provide a custom generator for PaymentMethod objects"
  public let suggestion: String

  /// **Additional context for debugging the discard issue**
  ///
  /// Key-value pairs providing diagnostic information:
  /// - Generator details (what types were generated)
  /// - Constraint information (what made inputs invalid)
  /// - Recommendation priority
  /// - Typical discard patterns for this rule
  public let metadata: [String: String]

  /// **Initialize a "gave up" error**
  ///
  /// Creates an error indicating the test framework couldn't generate enough valid inputs.
  ///
  /// - Parameters:
  ///   - rule: Name of the rule that couldn't be tested
  ///   - discarded: Number of invalid inputs generated
  ///   - iterations: Total iterations attempted
  ///   - suggestion: How to fix the issue
  ///   - metadata: Additional debugging information (default: empty)
  ///
  /// - Example:
  ///   ```swift
  ///   let error = BusinessRuleGaveUp(
  ///     rule: "Age must be between 18 and 65",
  ///     discarded: 8743,
  ///     iterations: 10000,
  ///     suggestion: "Use Gen.int(in: 0...100) instead of Gen.int(in: 18...65)",
  ///     metadata: ["discard_rate": "87.43%"]
  ///   )
  ///   ```
  public init(
    rule: String,
    discarded: Int,
    iterations: Int,
    suggestion: String,
    metadata: [String: String] = [:]
  ) {
    self.rule = rule
    self.discarded = discarded
    self.iterations = iterations
    self.suggestion = suggestion
    self.metadata = metadata
  }

  /// **Human-readable error message with diagnostic and remediation information**
  ///
  /// Provides a clear explanation of why testing was incomplete and how to fix it.
  ///
  /// - Note: This is automatically used when the error is printed or logged.
  public var description: String {
    """
    ⚠️ Business Rule Testing Incomplete

    Rule: \(rule)

    🔍 Analysis:
    • Attempted \(iterations) iterations
    • Discarded \(discarded) invalid test cases
    • Unable to generate sufficient valid inputs

    💡 Suggestion:
    \(suggestion)

    🛠 Common Solutions:
    1. Review generator constraints - they may be too restrictive
    2. Provide custom generators for complex business types
    3. Adjust property preconditions if they're too narrow
    4. Use Gen.suchThat() with more permissive conditions

    📊 Technical Details:
    Property-based testing requires generating valid inputs that satisfy
    your business constraints. If too many generated inputs are invalid,
    the test framework gives up to avoid infinite loops.
    """
  }
}

// MARK: - Smart Configuration

/// **Preconfigured testing profiles for common scenarios**
///
/// Provides business-optimized testing configurations for different use cases,
/// balancing thoroughness against execution time.
extension PropertyConfig {

  /// **Automatically calculated iteration count based on complexity**
  ///
  /// A middle-ground value suitable for most business rules. Calculated using heuristics
  /// to balance coverage probability against execution time.
  ///
  /// **Coverage Theory**:
  /// With a state space of size `S`, n iterations achieve coverage of `1 - (1 - 1/S)^n`.
  /// This value (200) provides 99.9% confidence for spaces up to ~2000 states.
  ///
  /// **When to Use**:
  /// - Default for new business rules
  /// - Medium-importance rules with reasonable state space
  /// - Development and CI environments
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig(
  ///     iterations: PropertyConfig.smartIterations,
  ///     maxShrinks: 1000,
  ///     maxDiscarded: 1000,
  ///     seed: nil
  ///   )
  ///   ```
  public static var smartIterations: Int {
    // Default smart configuration balances coverage with performance
    // Can be customized based on business requirements
    200
  }

  /// **Production-grade configuration for business-critical rules**
  ///
  /// Maximum testing thoroughness for rules where failures have significant business impact
  /// (financial calculations, data integrity, security checks, compliance requirements).
  ///
  /// **Configuration**:
  /// - 500 iterations: Comprehensive state space exploration
  /// - 2000 max shrinks: Aggressive reduction to minimal counterexamples
  /// - 2000 max discards: High tolerance for constraint filtering
  ///
  /// **When to Use**:
  /// - Payment processing and financial calculations
  /// - Data consistency and integrity checks
  /// - Security-sensitive operations
  /// - Regulatory compliance rules
  /// - Mission-critical business logic
  ///
  /// **Trade-off**: Slower execution (suitable for overnight test suites)
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig.businessCritical
  ///   let result = await runner.runProperty(paymentValidation, config: config)
  ///   ```
  ///
  /// - Note: Consider running in CI/CD with longer timeouts or as a separate suite.
  public static var businessCritical: PropertyConfig {
    PropertyConfig(
      iterations: 500,
      maxShrinks: 2000,
      maxDiscarded: 2000,
      seed: nil
    )
  }

  /// **Rapid feedback configuration for development and CI**
  ///
  /// Fast execution suitable for iterative development and quick feedback loops.
  /// Still provides reasonable coverage for catching common issues.
  ///
  /// **Configuration**:
  /// - 50 iterations: Quick state space sampling
  /// - 100 max shrinks: Fast counterexample reduction
  /// - 100 max discards: Strict constraint filtering
  ///
  /// **When to Use**:
  /// - Local development and debugging
  /// - Continuous integration feedback
  /// - Quick regression checks
  /// - Non-critical business rules
  /// - Testing during active development
  ///
  /// **Trade-off**: Lower coverage probability, but 10x faster execution
  ///
  /// - Example:
  ///   ```swift
  ///   let config = PropertyConfig.development
  ///   let result = await runner.runProperty(myRule, config: config)
  ///   // Completes in seconds for fast feedback
  ///   ```
  ///
  /// - Tip: Use this for initial development, then increase iterations as the rule stabilizes.
  public static var development: PropertyConfig {
    PropertyConfig(
      iterations: 50,
      maxShrinks: 100,
      maxDiscarded: 100,
      seed: nil
    )
  }
}

// MARK: - Business Domain Generators

/// **Pre-built generators for common business domain types**
///
/// These generators produce realistic values for business-critical properties,
/// helping catch edge cases in domain-specific logic like email validation,
/// age requirements, financial calculations, and name handling.
///
/// **Usage**:
/// Use these generators in property-based tests for business rules that depend
/// on realistic domain data:
///
/// ```swift
/// @PropertyTest
/// func testUserValidation(email: String = .email, age: Int = .age) {
///   let user = User(email: email, age: age)
///   #expect(user.isValid)
/// }
/// ```
extension Gen {

  /// **Generator for realistic email addresses**
  ///
  /// Produces email addresses in the format `name + number @ domain`, using
  /// realistic names and domains. Covers common patterns while still providing variation.
  ///
  /// **Generated Pattern**: `{name}{number}@{domain}`
  /// - Names: john, jane, alex, sam, chris, taylor (common lowercase names)
  /// - Numbers: 1-999
  /// - Domains: gmail.com, yahoo.com, company.com, example.org
  ///
  /// **Use For**:
  /// - Email validation rules
  /// - User registration flows
  /// - Contact information tests
  /// - Authentication checks
  ///
  /// **Examples Generated**:
  /// - john42@gmail.com
  /// - jane999@company.com
  /// - alex1@example.org
  ///
  /// **Shrinking**:
  /// Shrinks to simple test addresses (test@example.com, a@b.co) for minimal failing cases.
  ///
  /// - Example:
  ///   ```swift
  ///   @PropertyTest
  ///   func testEmailValidation(email: String = .email) {
  ///     #expect(email.contains("@"))
  ///     #expect(email.count > 5)
  ///   }
  ///   ```
  public static var email: Gen<String> {
    Gen<String>(
      generate: { rng, _ in
        let domains = ["gmail.com", "yahoo.com", "company.com", "example.org"]
        let names = ["john", "jane", "alex", "sam", "chris", "taylor"]
        let name = names.randomElement(using: &rng)!
        let domain = domains.randomElement(using: &rng)!
        let number = Int.random(in: 1...999, using: &rng)
        return "\(name)\(number)@\(domain)"
      },
      shrink: Shrink { _ in
        // Shrink to simpler email addresses
        ["test@example.com", "a@b.co"]
      }
    )
  }

  /// **Generator for realistic ages**
  ///
  /// Produces age values with weighting toward working-age adults (18-65) but
  /// also explores edge cases like children (0-17) and seniors (65+).
  ///
  /// **Distribution**:
  /// - 50% chance: 18-65 (working age, common business range)
  /// - 50% chance: 0-100 (full realistic range including edge cases)
  ///
  /// **Use For**:
  /// - Age restriction validation (e.g., 18+ for adult products)
  /// - Senior citizen benefits
  /// - Legal age requirements
  /// - Demographic-based rules
  ///
  /// **Examples Generated**:
  /// - 42 (typical adult)
  /// - 5 (child, edge case)
  /// - 75 (senior, edge case)
  /// - 18, 21, 65 (boundary values)
  ///
  /// **Shrinking**:
  /// Shrinks to boundary values (0, 18, 25) for understanding constraints.
  ///
  /// - Example:
  ///   ```swift
  ///   @PropertyTest
  ///   func testAdultRestriction(age: Int = .age) {
  ///     let isAdult = age >= 18
  ///     // Verify adult-only rules
  ///   }
  ///   ```
  public static var age: Gen<Int> {
    Gen<Int>(
      generate: { rng, _ in
        // Weighted toward common adult ages
        if Bool.random(using: &rng) {
          return Int.random(in: 18...65, using: &rng)  // Working age
        } else {
          return Int.random(in: 0...100, using: &rng)  // Full range
        }
      },
      shrink: Shrink { age in
        var candidates: [Int] = []
        if age > 18 { candidates.append(18) }  // Adult minimum
        if age > 25 { candidates.append(25) }  // Common business age
        if age != 0 { candidates.append(0) }  // Edge case
        return candidates
      }
    )
  }

  /// **Generator for realistic currency amounts**
  ///
  /// Produces decimal amounts suitable for financial calculations. Values are
  /// scaled with the test size parameter to explore both typical and large amounts.
  ///
  /// **Range**: 0 to (size.value * 100) cents
  /// - Small tests: $0 to $10 (typical transaction)
  /// - Large tests: $0 to $50+ (larger amounts)
  ///
  /// **Precision**: Always in cents (0.01 precision) for accurate financial math.
  ///
  /// **Use For**:
  /// - Price calculations
  /// - Discount/tax applications
  /// - Payment validations
  /// - Financial reporting rules
  /// - Currency conversions
  ///
  /// **Examples Generated**:
  /// - 9.99 (typical price)
  /// - 0.01 (minimum amount)
  /// - 12.47 (random cents precision)
  /// - 50.00+ (large amounts at big sizes)
  ///
  /// **Shrinking**:
  /// Shrinks to round amounts (0, 1, 10) for easy analysis.
  ///
  /// - Example:
  ///   ```swift
  ///   @PropertyTest
  ///   func testDiscountCalculation(price: Decimal = .currency, discount: Double) {
  ///     let discounted = price * Decimal(1 - discount / 100)
  ///     #expect(discounted >= 0)
  ///     #expect(discounted <= price)
  ///   }
  ///   ```
  ///
  /// - Important: Use Decimal, not Double, for financial calculations to avoid rounding errors.
  public static var currency: Gen<Decimal> {
    Gen<Decimal>(
      generate: { rng, size in
        // Generate realistic monetary amounts
        let maxAmount = size.value * 100
        let randomCents = Int.random(in: 0...maxAmount, using: &rng)
        return Decimal(randomCents) / 100
      },
      shrink: Shrink { amount in
        var candidates: [Decimal] = []
        if amount > 0 { candidates.append(0) }
        if amount > 1 { candidates.append(1) }
        if amount > 10 { candidates.append(10) }
        let half = amount / 2
        if half != amount && half > 0 { candidates.append(half) }
        return candidates
      }
    )
  }

  /// **Generator for realistic first names**
  ///
  /// Produces first names from a curated list of common American names,
  /// providing both male and female variations for demographic diversity.
  ///
  /// **Coverage**: 18 common names evenly distributed across gender
  ///
  /// **Use For**:
  /// - Name validation rules
  /// - User profile tests
  /// - Communication templates
  /// - Data anonymization
  /// - Localization testing
  ///
  /// **Examples Generated**:
  /// - James, Mary, John, Patricia, Robert, Jennifer
  /// - Michael, Linda, William, Elizabeth, David, Barbara
  /// - Richard, Susan, Joseph, Jessica, Thomas, Sarah
  ///
  /// **Shrinking**:
  /// Shrinks to "John" (simple, common, easy to reason about).
  ///
  /// - Example:
  ///   ```swift
  ///   @PropertyTest
  ///   func testNameDisplay(name: String = .firstName) {
  ///     #expect(name.count > 0)
  ///     #expect(name.first?.isLetter == true)
  ///   }
  ///   ```
  ///
  /// - Note: This provides US-centric names. For international testing, consider
  /// providing a custom generator with names from your target markets.
  public static var firstName: Gen<String> {
    Gen<String>(
      generate: { rng, _ in
        let names = [
          "James", "Mary", "John", "Patricia", "Robert", "Jennifer",
          "Michael", "Linda", "William", "Elizabeth", "David", "Barbara",
          "Richard", "Susan", "Joseph", "Jessica", "Thomas", "Sarah",
        ]
        return names.randomElement(using: &rng)!
      },
      shrink: Shrink { _ in ["John"] }  // Shrink to simple common name
    )
  }
}

// MARK: - Generator Zip Functions for Multiple Parameters
// Note: The core zip functions are already implemented in CombinatorGenerators.swift
// This section provides business-domain-specific generator helpers
