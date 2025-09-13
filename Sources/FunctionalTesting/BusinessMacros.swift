/// **Business-Friendly Property Testing Macros - Infrastructure**
///
/// This module provides the foundational types and protocols for business-friendly
/// property-based testing macros. It bridges the gap between mathematical property
/// testing and practical business validation through intelligent error reporting
/// and automatic test generation.
///
/// **Mathematical Foundation:**
/// Based on counterexample-guided abstraction refinement (CEGAR) principles,
/// transforming mathematical counterexamples into actionable business insights
/// while preserving the theoretical rigor of property-based testing.
///
/// **Architecture:**
/// - **BusinessRuleViolation**: Business-friendly error reporting with actionable remediation
/// - **ComplexityAnalyzer**: Smart iteration calculation based on function analysis
/// - **SmartGeneratable**: Protocol for automatic generator derivation
/// - **AutoTestable**: Protocol for comprehensive boundary testing
///
/// **External References:**
/// - [Counterexample-Guided Abstraction Refinement](https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement)
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
/// - [Computational Complexity Theory](https://en.wikipedia.org/wiki/Computational_complexity_theory)
/// - [Boundary Value Analysis](https://en.wikipedia.org/wiki/Boundary_value_analysis)

import Foundation

// MARK: - Business-Friendly Error Reporting

/// **Business-friendly error reporting for property test failures**
///
/// Transforms mathematical counterexamples into actionable business insights,
/// bridging the gap between formal property testing and practical business understanding.
/// This type serves as the foundation for @BusinessRule macro error reporting.
///
/// **Mathematical Foundation:**
/// Based on counterexample-guided abstraction refinement (CEGAR) principles,
/// providing minimal failing examples while maintaining business semantics.
/// The approach uses systematic shrinking to find the smallest counterexample
/// that violates the business rule, making debugging more accessible.
///
/// **CEGAR Process:**
/// 1. **Abstraction**: Business rule expressed as mathematical predicate
/// 2. **Model Checking**: Property testing searches the input domain
/// 3. **Counterexample**: Minimal failing case discovered through shrinking
/// 4. **Refinement**: Business-friendly interpretation with remediation suggestions
///
/// **Usage Examples:**
/// ```swift
/// @BusinessRule("Discount should never exceed product price")
/// func validateDiscount(product: Product, discount: Discount) -> Bool {
///     return discount.amount <= product.price
/// }
///
/// // When violation occurs, BusinessRuleViolation provides:
/// // - Human-readable rule description
/// // - Minimal counterexample (e.g., Product(price: 10), Discount(amount: 15))
/// // - Shrunk example showing the boundary case
/// // - Business impact explanation
/// // - Actionable remediation steps
/// ```
///
/// **Business Impact Categories:**
/// - **Critical**: Immediate business risk (financial loss, security breach)
/// - **High**: Significant business impact (customer experience, data integrity)
/// - **Medium**: Moderate business concern (performance, usability)
/// - **Low**: Minor business consideration (edge cases, cosmetic issues)
///
/// **External References:**
/// - [Counterexample-Guided Abstraction Refinement](https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement)
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
/// - [Software Testing Theory](https://en.wikipedia.org/wiki/Software_testing)
public struct BusinessRuleViolation: Error, @unchecked Sendable {
  /// The business rule that was violated
  ///
  /// Human-readable description of the business constraint that failed,
  /// designed for non-technical stakeholders to understand the issue.
  public let rule: String

  /// The minimal counterexample that violates the rule
  ///
  /// The original failing input discovered during property testing.
  /// This represents the raw counterexample before shrinking optimization.
  public let counterexample: BusinessRuleCounterexample

  /// The shrunk counterexample for debugging
  ///
  /// The minimal failing case after systematic shrinking, providing
  /// the smallest possible input that still violates the business rule.
  /// This follows CEGAR refinement principles for optimal debugging.
  public let shrunk: BusinessRuleCounterexample

  /// Business impact description
  ///
  /// Clear explanation of what this violation means for the business,
  /// including potential consequences and stakeholder impact.
  public let businessImpact: String

  /// Suggested remediation actions
  ///
  /// Actionable steps that developers and business stakeholders can take
  /// to address this violation and prevent similar issues in the future.
  public let remediation: [String]

  /// Number of iterations before failure
  ///
  /// The iteration count when the violation was discovered, providing
  /// context about the test's progress and coverage.
  public let iterations: Int

  /// Severity level for business stakeholders
  ///
  /// Risk categorization helping business stakeholders prioritize
  /// remediation efforts based on potential business impact.
  public let severity: BusinessImpactSeverity

  /// Initialize a new business rule violation
  ///
  /// - Parameters:
  ///   - rule: Human-readable description of the violated business rule
  ///   - counterexample: The original failing input case
  ///   - shrunk: The minimal failing case after shrinking
  ///   - businessImpact: Business explanation of the violation's consequences
  ///   - remediation: Actionable steps to address the violation (default: empty)
  ///   - iterations: Test iterations completed before failure
  ///   - severity: Business impact severity level (default: .high)
  public init(
    rule: String,
    counterexample: BusinessRuleCounterexample,
    shrunk: BusinessRuleCounterexample,
    businessImpact: String,
    remediation: [String] = [],
    iterations: Int,
    severity: BusinessImpactSeverity = .high
  ) {
    self.rule = rule
    self.counterexample = counterexample
    self.shrunk = shrunk
    self.businessImpact = businessImpact
    self.remediation = remediation
    self.iterations = iterations
    self.severity = severity
  }
}

/// **Business impact severity levels for risk categorization**
///
/// Provides standardized risk levels that help business stakeholders
/// understand and prioritize the remediation of rule violations.
/// Based on common business risk assessment frameworks.
///
/// **Severity Guidelines:**
/// - **Critical**: Data corruption, financial loss, security vulnerabilities
/// - **High**: Customer impact, compliance violations, system failures
/// - **Medium**: Performance degradation, usability issues, minor data inconsistencies
/// - **Low**: Edge cases, cosmetic issues, documentation gaps
///
/// **Usage in Business Rules:**
/// ```swift
/// @BusinessRule("Customer payment processing must be atomic")
/// func validatePaymentAtomicity(payment: Payment) -> Bool {
///     // Financial operations are typically critical severity
///     return payment.isAtomic && payment.hasRollback
/// }
/// ```
public enum BusinessImpactSeverity: String, Sendable, CaseIterable {
  /// **Critical - Immediate business risk**
  ///
  /// Violations that pose immediate threats to business operations,
  /// including financial loss, security breaches, or data corruption.
  /// Requires immediate attention and emergency response procedures.
  case critical = "Critical - Immediate business risk"

  /// **High - Significant business impact**
  ///
  /// Violations that significantly impact business operations or customer experience,
  /// including system failures, compliance violations, or major functionality issues.
  /// Should be addressed within the current development cycle.
  case high = "High - Significant business impact"

  /// **Medium - Moderate business concern**
  ///
  /// Violations that moderately impact business operations or user experience,
  /// including performance issues, minor data inconsistencies, or usability problems.
  /// Should be addressed in upcoming releases based on priority.
  case medium = "Medium - Moderate business concern"

  /// **Low - Minor business consideration**
  ///
  /// Violations that have minimal business impact, including edge cases,
  /// cosmetic issues, or minor documentation gaps.
  /// Can be addressed during maintenance cycles or future enhancements.
  case low = "Low - Minor business consideration"

  /// Numeric priority for sorting and triage operations
  ///
  /// Provides a comparable numeric value for automated prioritization systems.
  /// Higher values indicate higher priority for business attention.
  public var priority: Int {
    switch self {
    case .critical: return 4
    case .high: return 3
    case .medium: return 2
    case .low: return 1
    }
  }
}

// MARK: - Smart Iteration Calculation

/// **Intelligent iteration calculation for business rules**
///
/// Determines appropriate test iteration counts based on function complexity,
/// parameter types, and business risk assessment. This enables the @BusinessRule
/// macro to automatically optimize test thoroughness while maintaining reasonable
/// execution times.
///
/// **Mathematical Foundation:**
/// Based on computational complexity theory and empirical analysis of
/// property testing effectiveness vs iteration count relationships.
/// Uses cyclomatic complexity, parameter analysis, and business domain
/// heuristics to calculate optimal test coverage.
///
/// **Complexity Scoring Algorithm:**
/// 1. **Parameter Complexity**: Base score from parameter count and types
/// 2. **Business Risk Factor**: Multiplier based on domain-specific keywords
/// 3. **Body Complexity**: Additional scoring from function structure
/// 4. **Final Calculation**: `(parameterComplexity + bodyComplexity) * riskFactor`
///
/// **Iteration Mapping:**
/// - Low complexity (1-5): 50-250 iterations
/// - Medium complexity (6-15): 250-750 iterations
/// - High complexity (16-30): 750-1500 iterations
/// - Very high complexity (30+): 1500-2000 iterations (capped)
///
/// **External References:**
/// - [Computational Complexity Theory](https://en.wikipedia.org/wiki/Computational_complexity_theory)
/// - [Cyclomatic Complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
/// - [Property-Based Testing Effectiveness](https://dl.acm.org/doi/10.1145/351240.351266)
public struct ComplexityAnalyzer: Sendable {
  /// **Complexity scoring for functions and parameter types**
  ///
  /// Represents the analyzed complexity of a function based on its parameters,
  /// structure, and business domain risk factors. This scoring drives the
  /// intelligent iteration calculation for property-based testing.
  ///
  /// **Scoring Components:**
  /// - **Parameter Complexity**: Based on count and semantic analysis of parameter names
  /// - **Body Complexity**: Static analysis of function structure (future enhancement)
  /// - **Risk Factor**: Business domain multiplier (financial = 1.5x, general = 1.0x)
  ///
  /// **Total Complexity Calculation:**
  /// `totalComplexity = (parameterComplexity + bodyComplexity) * riskFactor`
  ///
  /// **Usage in Macro Generation:**
  /// ```swift
  /// let complexity = ComplexityAnalyzer.analyzeFunction(
  ///     parameterTypes: ["Decimal", "Int", "String"],
  ///     parameterNames: ["price", "quantity", "currency"]
  /// )
  /// let iterations = ComplexityAnalyzer.recommendIterations(for: complexity)
  /// // Result: Higher iterations due to financial domain keywords
  /// ```
  public struct ComplexityScore: Sendable {
    /// Parameter-based complexity scoring
    ///
    /// Calculated from parameter count plus semantic analysis bonuses
    /// for business-critical parameter names (price, amount, etc.).
    public let parameterComplexity: Int

    /// Function body complexity scoring
    ///
    /// Reserved for future static analysis of function structure.
    /// Currently defaults to 1 but can be enhanced with cyclomatic complexity analysis.
    public let bodyComplexity: Int

    /// Business domain risk multiplier
    ///
    /// Amplifies complexity for business-critical domains:
    /// - Financial operations: 1.5x multiplier
    /// - General business logic: 1.0x multiplier
    public let riskFactor: Double

    /// Total complexity after risk adjustment
    ///
    /// The final complexity score used for iteration calculation,
    /// combining all factors with business risk amplification.
    public var totalComplexity: Int {
      Int(Double(parameterComplexity + bodyComplexity) * riskFactor)
    }
  }

  /// **Recommend iteration count based on complexity analysis**
  ///
  /// Calculates the optimal number of property testing iterations based on
  /// the analyzed complexity score. Uses empirically-derived mapping between
  /// complexity and testing effectiveness to balance thoroughness with performance.
  ///
  /// **Algorithm:**
  /// 1. Calculate base iterations: `max(50, complexity.totalComplexity * 10)`
  /// 2. Apply performance cap: `min(baseIterations, 2000)`
  /// 3. Ensure minimum coverage: Always at least 50 iterations
  ///
  /// **Complexity-to-Iteration Mapping:**
  /// - Very Low (1-2): 50-100 iterations (minimum coverage)
  /// - Low (3-5): 100-250 iterations (basic validation)
  /// - Medium (6-15): 250-750 iterations (thorough testing)
  /// - High (16-30): 750-1500 iterations (comprehensive validation)
  /// - Very High (30+): 1500-2000 iterations (maximum feasible)
  ///
  /// - Parameter complexity: The complexity analysis result from function analysis
  /// - Returns: Recommended iteration count optimized for the function's complexity
  public static func recommendIterations(for complexity: ComplexityScore) -> Int {
    let baseIterations = max(50, complexity.totalComplexity * 10)
    return min(baseIterations, 2000)  // Cap at 2000 for performance
  }

  /// **Calculate base iterations before risk adjustment**
  ///
  /// Provides the iteration count based purely on structural complexity,
  /// before applying business risk factors. Useful for adaptive iteration
  /// strategies that need to understand the baseline complexity.
  ///
  /// **Algorithm:**
  /// `parameterComplexity * 25 + bodyComplexity * 10`
  ///
  /// This weighting emphasizes parameter complexity as the primary driver
  /// of testing requirements, with body complexity as a secondary factor.
  ///
  /// - Parameter complexity: The complexity analysis result
  /// - Returns: Base iteration count without risk factor amplification
  public static func baseIterations(for complexity: ComplexityScore) -> Int {
    complexity.parameterComplexity * 25 + complexity.bodyComplexity * 10
  }

  /// **Analyze function complexity from parameter types and names**
  ///
  /// Performs static analysis of function signature to determine complexity
  /// scoring for intelligent iteration calculation. This is the primary
  /// entry point for macro-generated complexity analysis.
  ///
  /// **Analysis Process:**
  /// 1. **Parameter Count**: Base complexity from number of parameters
  /// 2. **Semantic Analysis**: Risk scoring from parameter names
  /// 3. **Risk Factor Calculation**: Business domain multiplier
  /// 4. **Complexity Score Assembly**: Combine all factors
  ///
  /// **Parameter Name Risk Keywords:**
  /// - High Risk: price, amount, balance, rate, percent, currency, money
  /// - Risk Bonus: +2 complexity points per matching parameter
  ///
  /// **Business Risk Factors:**
  /// - Financial Domain: 1.5x multiplier (contains financial keywords)
  /// - General Domain: 1.0x multiplier (no financial keywords detected)
  ///
  /// - Parameters:
  ///   - parameterTypes: Array of Swift type names for analysis
  ///   - parameterNames: Array of parameter names for semantic analysis
  ///   - bodyComplexity: Function body complexity (default: 1, reserved for future enhancement)
  /// - Returns: ComplexityScore with all analysis results
  public static func analyzeFunction(
    parameterTypes: [String],
    parameterNames: [String],
    bodyComplexity: Int = 1
  ) -> ComplexityScore {
    let paramComplexity =
      parameterTypes.count + parameterNames.reduce(0) { $0 + riskScore(for: $1) }

    return ComplexityScore(
      parameterComplexity: paramComplexity,
      bodyComplexity: bodyComplexity,
      riskFactor: calculateRiskFactor(parameterNames: parameterNames)
    )
  }

  /// Calculate risk bonus points for parameter names
  ///
  /// Analyzes parameter names for business-critical keywords that indicate
  /// higher testing requirements. Financial and monetary terms receive
  /// additional complexity points due to their business importance.
  private static func riskScore(for name: String) -> Int {
    let highRiskKeywords = [
      "price", "amount", "balance", "rate", "percent", "currency", "money", "cost", "fee",
      "discount", "tax",
    ]
    return highRiskKeywords.contains { name.lowercased().contains($0) } ? 2 : 0
  }

  /// Calculate business domain risk factor multiplier
  ///
  /// Determines if the function operates in a high-risk business domain
  /// based on parameter naming patterns. Financial operations receive
  /// amplified complexity scoring due to their critical business impact.
  private static func calculateRiskFactor(parameterNames: [String]) -> Double {
    let financialKeywords = [
      "price", "amount", "money", "currency", "rate", "balance", "cost", "fee", "payment",
      "transaction",
    ]
    let hasFinancialTerms = parameterNames.contains { name in
      financialKeywords.contains { name.lowercased().contains($0) }
    }
    return hasFinancialTerms ? 1.5 : 1.0
  }
}

/// **Intelligent iteration calculation for business rules**
///
/// Provides flexible iteration strategies for @BusinessRule macro that balance
/// testing thoroughness with execution performance. Enables automatic optimization
/// based on function complexity analysis while allowing manual overrides.
///
/// **Strategy Types:**
/// - **Smart**: Automatic calculation using ComplexityAnalyzer (recommended)
/// - **Fixed**: Explicit iteration count for predictable testing
/// - **Adaptive**: Range-based with complexity-driven selection
///
/// **Smart Algorithm:**
/// Uses ComplexityAnalyzer to determine optimal iterations based on:
/// - Parameter count and semantic analysis
/// - Business domain risk factors
/// - Empirical testing effectiveness curves
///
/// **Usage in Business Rules:**
/// ```swift
/// @BusinessRule("Order total calculation", iterations: .smart)
/// func validateOrderTotal(order: Order) -> Bool {
///     // Automatically calculates ~150-300 iterations based on complexity
///     return order.total == order.items.map(\.price).reduce(0, +)
/// }
///
/// @BusinessRule("Critical payment validation", iterations: .fixed(1000))
/// func validatePayment(payment: Payment) -> Bool {
///     // Explicit 1000 iterations for critical financial operations
///     return payment.amount > 0 && payment.isValid
/// }
/// ```
public enum BusinessRuleIterations: Sendable {
  /// **Automatically determine iterations using complexity analysis**
  ///
  /// Recommended strategy that uses ComplexityAnalyzer to calculate
  /// optimal iteration counts based on function signature analysis.
  /// Provides the best balance of thoroughness and performance.
  case smart

  /// **Fixed number of iterations**
  ///
  /// Explicit iteration count for predictable testing behavior.
  /// Useful for critical business rules requiring guaranteed coverage
  /// or for performance-sensitive testing scenarios.
  case fixed(Int)

  /// **Adaptive range based on complexity scoring**
  ///
  /// Complexity-driven selection within specified bounds.
  /// Provides smart optimization with explicit performance limits,
  /// useful for balancing thoroughness with execution time constraints.
  case adaptive(min: Int, max: Int)

  /// **Resolve to concrete iteration count**
  ///
  /// Converts the iteration strategy to a specific number based on
  /// the provided complexity analysis. This method is called by
  /// the @BusinessRule macro during test generation.
  ///
  /// **Resolution Algorithm:**
  /// - **Smart**: Uses ComplexityAnalyzer.recommendIterations()
  /// - **Fixed**: Returns the specified count (minimum 1)
  /// - **Adaptive**: Calculates base iterations, constrains to range
  ///
  /// - Parameter complexity: Function complexity analysis from ComplexityAnalyzer
  /// - Returns: Concrete iteration count for property testing execution
  func resolve(for complexity: ComplexityAnalyzer.ComplexityScore) -> Int {
    switch self {
    case .smart:
      return ComplexityAnalyzer.recommendIterations(for: complexity)

    case .fixed(let count):
      return max(1, count)

    case .adaptive(let min, let max):
      let base = ComplexityAnalyzer.baseIterations(for: complexity)
      return Swift.min(Swift.max(base, min), max)
    }
  }
}

// MARK: - Smart Generator Infrastructure

/// **Protocol for automatic generator derivation based on type structure and naming**
///
/// Enables automatic generation of realistic test data based on property names,
/// types, and business domain conventions. Implements type-directed generation
/// with semantic inference capabilities that eliminate boilerplate generator code.
///
/// **Mathematical Foundation:**
/// Based on dependent type theory and semantic analysis, where generator selection
/// depends on both static type information and semantic context from naming patterns.
/// The approach uses type-level programming concepts to automatically derive
/// appropriate generators that satisfy business domain constraints.
///
/// **Type-Directed Generation Algorithm:**
/// 1. **Structural Analysis**: Examine type definition for properties and their types
/// 2. **Semantic Inference**: Analyze property names for business domain patterns
/// 3. **Generator Selection**: Choose appropriate generators based on combined analysis
/// 4. **Constraint Application**: Apply business constraints and edge case probabilities
/// 5. **Composition**: Combine individual property generators into type generator
///
/// **Laws (Mathematical Properties):**
/// - **Consistency Law**: `T.smartGen.generate()` must produce valid instances of `T`
/// - **Coverage Law**: Generated values should cover practical business value ranges
/// - **Shrinking Law**: Generated values must shrink to simpler business-meaningful values
///
/// **Usage Examples:**
/// ```swift
/// @SmartGenerator
/// struct Customer {
///     let id: UUID            // → Gen.uuid
///     let name: String        // → Gen.personName (inferred from property name)
///     let email: String       // → Gen.email (inferred from property name)
///     let age: Int            // → Gen.age (inferred from property name)
///     let balance: Decimal    // → Gen.currency (inferred from property name)
/// }
///
/// // Automatically generates:
/// extension Customer: SmartGeneratable {
///     static var smartGen: Gen<Customer> {
///         Gen.zip5(Gen.uuid, Gen.personName, Gen.email, Gen.age, Gen.currency)
///             .map(Customer.init)
///     }
/// }
///
/// // Usage in business rules:
/// @BusinessRule("Customer balance should be non-negative")
/// func validateCustomerBalance(customer: Customer) -> Bool {
///     return customer.balance >= 0
/// }
/// ```
///
/// **Domain-Specific Inference Patterns:**
/// - **Financial**: price, amount, cost, fee → Gen.currency
/// - **Personal**: name, firstName, lastName → Gen.personName
/// - **Contact**: email, phone → Gen.email, Gen.phoneNumber
/// - **Demographics**: age, birthDate → Gen.age, Gen.birthDate
/// - **Geographic**: address, city, country → Gen.address, Gen.city
/// - **Temporal**: date, time, timestamp → Gen.date, Gen.time
///
/// **Business Realism Modes:**
/// - **Realistic Mode**: Generates business-appropriate values within normal ranges
/// - **Comprehensive Mode**: Includes edge cases, extreme values, and boundary conditions
/// - **Custom Constraints**: Allows fine-tuned control over generation parameters
///
/// **External References:**
/// - [Dependent Type Theory](https://en.wikipedia.org/wiki/Dependent_type)
/// - [Semantic Analysis in Compilers](https://en.wikipedia.org/wiki/Semantic_analysis_(compilers))
/// - [Type-Directed Programming](https://en.wikipedia.org/wiki/Type_system#Type-directed_programming)
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
public protocol SmartGeneratable {
  /// **Automatically derived generator for this type**
  ///
  /// The generator produces business-realistic values that cover edge cases
  /// and common patterns for the domain while maintaining mathematical rigor.
  /// Generated values follow the laws of consistency, coverage, and shrinking.
  ///
  /// **Generator Characteristics:**
  /// - **Consistency**: Always produces valid instances that satisfy type constraints
  /// - **Business Relevance**: Values appropriate for real business scenarios
  /// - **Edge Case Coverage**: Includes boundary conditions and problematic values
  /// - **Shrinking Support**: Values shrink to simpler, debuggable counterexamples
  /// - **Performance**: Efficient generation with O(1) average case complexity
  ///
  /// **Implementation Notes:**
  /// This property is typically implemented by the @SmartGenerator macro through
  /// automatic analysis of type structure and property naming conventions.
  /// Manual implementation is supported for complex types requiring custom logic.
  static var smartGen: Gen<Self> { get }
}

/// **Generator constraints for controlling smart generation behavior**
///
/// Provides fine-grained control over automatic generator derivation, allowing
/// developers to balance between business realism and comprehensive edge case testing.
/// Constraints influence both value ranges and edge case probability distributions.
///
/// **Design Philosophy:**
/// The constraint system follows a declarative approach where developers specify
/// what they want (business-realistic vs comprehensive testing) rather than how
/// to achieve it. The system automatically translates high-level constraints
/// into appropriate generator configurations.
///
/// **Mathematical Model:**
/// Constraints are modeled as probability distributions over value domains:
/// - **Value Range**: [minValue, maxValue] defines the support of the distribution
/// - **Business Realism**: Biases distribution toward typical business values
/// - **Edge Case Probability**: Controls frequency of boundary and extreme values
/// - **Null Handling**: Manages Optional type generation frequencies
///
/// **Usage Examples:**
/// ```swift
/// // Business-realistic constraints (default)
/// @SmartGenerator(constraints: .realistic)
/// struct Product {
///     let price: Decimal      // Generates $0.01 - $10,000 with business distribution
///     let quantity: Int       // Generates 1 - 1000 with realistic frequency
/// }
///
/// // Comprehensive testing constraints
/// @SmartGenerator(constraints: .comprehensive)
/// struct Product {
///     let price: Decimal      // Includes edge cases: 0, negative, very large values
///     let quantity: Int       // Includes edge cases: 0, negative, Int.max
/// }
///
/// // Custom constraints
/// @SmartGenerator(constraints: .custom(
///     minValue: 0,
///     maxValue: 1000000,
///     businessRealistic: false,
///     edgeCaseProbability: 0.3
/// ))
/// struct HighVolumeProduct {
///     let unitsSold: Int      // Custom range with 30% edge case probability
/// }
/// ```
///
/// **Constraint Interaction Matrix:**
/// - **Realistic + Low Edge Probability**: Pure business scenarios
/// - **Realistic + High Edge Probability**: Business scenarios with edge cases
/// - **Comprehensive + Low Edge Probability**: Wide range testing
/// - **Comprehensive + High Edge Probability**: Exhaustive edge case testing
///
/// **Performance Implications:**
/// - **Realistic Mode**: Faster generation, focused testing
/// - **Comprehensive Mode**: Slower generation, broader coverage
/// - **Edge Case Probability**: Linear impact on generation time
/// - **Null Handling**: Minimal performance impact
public struct GeneratorConstraints: Sendable {
  /// **Minimum value constraint for numeric generators**
  ///
  /// When specified, constrains numeric generators to produce values >= minValue.
  /// Applies to Int, Double, Decimal, and other numeric types.
  /// Nil value indicates no lower bound constraint.
  public let minValue: Double?

  /// **Maximum value constraint for numeric generators**
  ///
  /// When specified, constrains numeric generators to produce values <= maxValue.
  /// Applies to Int, Double, Decimal, and other numeric types.
  /// Nil value indicates no upper bound constraint.
  public let maxValue: Double?

  /// **Enable null generation for Optional types**
  ///
  /// Controls whether generators for Optional<T> types produce nil values.
  /// When true, approximately 10% of generated Optional values will be nil.
  /// When false, Optional generators always produce non-nil values.
  public let allowNull: Bool

  /// **Enable business-realistic value distribution**
  ///
  /// When true, generators bias toward values commonly seen in business scenarios:
  /// - Prices: $1-$1000 range favored over extreme values
  /// - Ages: 18-65 range favored over boundary cases
  /// - Quantities: 1-100 range favored over very large numbers
  ///
  /// When false, generators use uniform distribution across the entire type range.
  public let businessRealistic: Bool

  /// **Probability of generating edge case values**
  ///
  /// Controls the frequency of boundary conditions and extreme values:
  /// - 0.0: No edge cases (pure typical values)
  /// - 0.1: 10% edge cases (recommended for business testing)
  /// - 0.3: 30% edge cases (thorough validation)
  /// - 0.5: 50% edge cases (stress testing)
  ///
  /// Edge cases include: zero, negative values, type boundaries, empty collections.
  public let edgeCaseProbability: Double

  /// **Initialize custom generator constraints**
  ///
  /// Creates a constraint configuration with explicit control over all parameters.
  /// This initializer provides maximum flexibility for specialized testing scenarios.
  ///
  /// - Parameters:
  ///   - minValue: Minimum numeric value constraint (default: nil)
  ///   - maxValue: Maximum numeric value constraint (default: nil)
  ///   - allowNull: Enable null generation for Optional types (default: true)
  ///   - businessRealistic: Use business-realistic value distributions (default: true)
  ///   - edgeCaseProbability: Probability of edge case generation (default: 0.1)
  public init(
    minValue: Double? = nil,
    maxValue: Double? = nil,
    allowNull: Bool = true,
    businessRealistic: Bool = true,
    edgeCaseProbability: Double = 0.1
  ) {
    precondition(
      edgeCaseProbability >= 0.0 && edgeCaseProbability <= 1.0,
      "edgeCaseProbability must be between 0.0 and 1.0"
    )

    if let min = minValue, let max = maxValue {
      precondition(min <= max, "minValue must be <= maxValue")
    }

    self.minValue = minValue
    self.maxValue = maxValue
    self.allowNull = allowNull
    self.businessRealistic = businessRealistic
    self.edgeCaseProbability = edgeCaseProbability
  }

  /// **Realistic business testing constraints (default)**
  ///
  /// Optimized for typical business scenarios with minimal edge cases.
  /// Provides good coverage of common business value ranges while maintaining
  /// fast test execution and focused failure detection.
  ///
  /// **Configuration:**
  /// - Business-realistic distributions enabled
  /// - 10% edge case probability
  /// - Null values allowed for Optional types
  /// - No explicit min/max bounds (type defaults used)
  public static let realistic = Self(
    businessRealistic: true,
    edgeCaseProbability: 0.1
  )

  /// **Comprehensive edge case testing constraints**
  ///
  /// Optimized for thorough validation including boundary conditions and extreme values.
  /// Provides maximum coverage at the cost of slower test execution and more
  /// complex failure scenarios.
  ///
  /// **Configuration:**
  /// - Uniform distribution across full type range
  /// - 30% edge case probability
  /// - Null values allowed for Optional types
  /// - No explicit min/max bounds (full type range tested)
  public static let comprehensive = Self(
    businessRealistic: false,
    edgeCaseProbability: 0.3
  )

  /// **Conservative constraints for critical business rules**
  ///
  /// Minimizes edge cases and focuses on core business value ranges.
  /// Recommended for critical financial calculations and high-risk business logic
  /// where failures must be immediately actionable.
  ///
  /// **Configuration:**
  /// - Business-realistic distributions enabled
  /// - 5% edge case probability (minimal)
  /// - Null values disabled for Optional types
  /// - Conservative ranges for numeric types
  public static let conservative = Self(
    minValue: 0,
    allowNull: false,
    businessRealistic: true,
    edgeCaseProbability: 0.05
  )
}

// MARK: - BusinessRuleCounterexample Helper

/// Type-erased Sendable wrapper for counterexample storage
///
/// Provides a safe way to store arbitrary counterexample values in
/// BusinessRuleViolation while maintaining Swift 6 concurrency safety.
/// This wrapper ensures thread-safe access to shrunk values across
/// actor boundaries during error reporting.
public struct BusinessRuleCounterexample: @unchecked Sendable {
  private let _value: Any

  /// Wrap any value as Sendable
  ///
  /// Creates a type-erased wrapper that assumes the provided value
  /// is safe for concurrent access. Use with caution and ensure
  /// the wrapped value is actually thread-safe.
  public init<T>(_ value: T) {
    self._value = value
  }

  /// Access the underlying value
  ///
  /// Retrieves the original value with type casting.
  /// Returns nil if the requested type doesn't match the stored type.
  public func value<T>(as type: T.Type) -> T? {
    _value as? T
  }

  /// Access the underlying value as Any
  ///
  /// Provides direct access to the stored value without type constraints.
  /// Useful for debugging and logging purposes.
  public var anyValue: Any {
    _value
  }
}

extension BusinessRuleCounterexample: CustomStringConvertible {
  public var description: String {
    String(describing: _value)
  }
}

extension BusinessRuleCounterexample: CustomDebugStringConvertible {
  public var debugDescription: String {
    "BusinessRuleCounterexample(\(String(reflecting: _value)))"
  }
}
