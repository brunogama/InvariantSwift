# Phase 1: Core Business Macros - Enhanced Specification

> Normalized on 2025-09-13T22:29:32Z using spec.template.md

## Title

Phase 1: Core Business Macros - Enhanced Specification

## Executive Summary

<!-- chunk 1 -->
### Overview

Phase 1 establishes the foundation for user-friendly property-based testing by implementing core business macros that eliminate mathematical complexity. This enhanced specification focuses on the most valuable and implementable macros that leverage the existing FunctionalTesting infrastructure.

**Timeline**: 4-6 weeks  
**Priority**: CRITICAL - Foundation for all subsequent phases  
**Integration**: Direct integration with existing Property/Gen/PropertyRunner system  
**Swift Version**: Swift 6.0+ with strict concurrency  
**Architecture**: SwiftSyntax-based macros with category theory foundations

## Problem Statement

_TBD_

## Goals and Objectives

_TBD_

## Non-Goals

_TBD_

## Scope

_TBD_

## User Personas and Use Cases

_TBD_

## Functional Requirements

<!-- chunk 1 -->
### Functional Requirements

- [ ] Zero mathematical knowledge required for @BusinessRule usage
- [ ] 80% reduction in boilerplate code for test data generation
- [ ] Automatic boundary testing for 90% of common Swift types
- [ ] Business-friendly error messages with actionable suggestions

## Non-Functional Requirements

_TBD_

## Architecture Overview

_TBD_

## System Components

_TBD_

## Data Model

_TBD_

## APIs and Contracts

<!-- chunk 1 -->
### API Documentation (100% coverage requirement)

1. **Complete Macro Reference**
   - All macro parameters with examples
   - Generated code patterns
   - Error conditions and handling
   - Performance implications

2. **Generator Library for Business Domains**
   - Pre-built generators for common types
   - Composition patterns
   - Custom constraint examples
   - Integration with existing generators

3. **Error Handling and Troubleshooting Guide**
   - BusinessRuleViolation interpretation
   - Common failure patterns
   - Debugging shrinking results
   - Performance optimization

## Workflows and Sequence Diagrams

_TBD_

## State Management and Concurrency

_TBD_

## Security and Compliance

_TBD_

## Performance and Capacity

_TBD_

## Observability and Telemetry

_TBD_

## Error Handling and Resilience

_TBD_

## Testing Strategy

<!-- chunk 1 -->
### Testing Requirements

- [ ] 99% code coverage for all macro-generated code
- [ ] Integration tests with real business scenarios
- [ ] Performance regression tests
- [ ] Cross-platform compatibility validation
- [ ] Error condition coverage

## Release Plan and Migration

_TBD_

## Risks and Mitigations

_TBD_

## Assumptions and Constraints

<!-- chunk 1 -->
### Dependencies and Constraints

- **SwiftSyntax**: 509.0.0 - 602.0.0 (current package dependency)
- **Swift Testing**: Native integration through @Test attribute generation
- **Concurrency**: Full Swift 6 actor isolation compliance required
- **Performance Target**: <20% compilation time impact, >99% test coverage
- **Documentation**: Complete DocC coverage with mathematical foundations

## Open Questions

_TBD_

## Milestones and Timeline

_TBD_

## Acceptance Criteria / DoD

_TBD_

## Operational Runbook

_TBD_

## Glossary

_TBD_

## References

<!-- chunk 1 -->
### Enhanced Macro Selection

Based on functional programming analysis and business value assessment, the following macros have been retained and enhanced:

<!-- chunk 2 -->
### ✅ CRITICAL PRIORITY

<!-- Empty section ✅ CRITICAL PRIORITY -->

<!-- chunk 3 -->
### 1. `@BusinessRule` Macro ⭐ **IMPLEMENT FIRST**

**Business Value**: Transforms mathematical property testing into business-friendly validation  
**Implementation Complexity**: Medium (leverages existing Property infrastructure)  
**Integration Points**: Property<T>, PropertyRunner, PropertyConfig

<!-- chunk 4 -->
### Enhanced Design

```swift
@attached(peer, names: suffixed(_PropertyTest))
public macro BusinessRule(
    _ description: String,
    iterations: BusinessRuleIterations = .smart,
    timeout: TimeInterval = 30.0
) = #externalMacro(module: "FunctionalTestingMacros", type: "BusinessRuleMacro")

/// Intelligent iteration calculation for business rules
/// 
/// Determines appropriate test iteration counts based on function complexity,
/// parameter types, and business risk assessment.
public enum BusinessRuleIterations: Sendable {
    /// Automatically determine iterations using complexity analysis
    case smart
    /// Fixed number of iterations
    case fixed(Int)
    /// Adaptive range based on complexity scoring
    case adaptive(min: Int, max: Int)
    
    /// Resolve to concrete iteration count
    func resolve(for complexity: ComplexityScore) -> Int {
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
```

<!-- chunk 5 -->
### Key Enhancements from Original:

- **Simplified API**: Removed complex configuration options that add no business value
- **Smart Defaults**: Automatic iteration calculation based on existing ComplexityAnalyzer patterns
- **Direct Integration**: Uses existing Property<T> and PropertyRunner infrastructure
- **Business Error Reporting**: Clear, actionable error messages for business stakeholders

<!-- chunk 6 -->
### Generated Code Pattern

```swift
// Input:
@BusinessRule("Discount should never exceed product price")
func validateDiscount(product: Product, discount: Discount) -> Bool {
    return discount.amount <= product.price
}

// Generated (leveraging existing infrastructure):
@Test("Business Rule: Discount should never exceed product price")
func validateDiscount_PropertyTest() async throws {
    let property = Property<(Product, Discount)>(
        generator: Gen.zip(Product.smartGen, Discount.smartGen),
        predicate: { (product, discount) in
            validateDiscount(product: product, discount: discount)
        }
    )
    
    let result = await PropertyRunner().runProperty(property)
    
    if case .failure(let counterexample, _, let shrunk) = result {
        throw BusinessRuleViolation(
            rule: "Discount should never exceed product price",
            counterexample: counterexample,
            shrunk: shrunk,
            businessImpact: "Customer may receive invalid discounts, leading to financial loss",
            remediation: [
                "Implement discount validation before applying to cart",
                "Add maximum discount percentage limits in business rules",
                "Review discount calculation logic for edge cases"
            ],
            iterations: result.completedIterations
        )
    }
    
    #expect(result.isSuccess, "Business rule validation failed")
}
```

<!-- chunk 7 -->
### 2. `@SmartGenerator` Macro ⭐ **HIGH PRIORITY**

**Business Value**: Eliminates 80%+ of boilerplate test data generation code  
**Implementation Complexity**: Medium (extends existing Gen system)  
**Integration Points**: Gen<T>, existing generator combinators

<!-- chunk 8 -->
### Enhanced Design

```swift
@attached(member, names: named(smartGen))
@attached(extension, conformances: SmartGeneratable)
public macro SmartGenerator(
    constraints: GeneratorConstraints = .realistic
) = #externalMacro(module: "FunctionalTestingMacros", type: "SmartGeneratorMacro")
```

<!-- chunk 9 -->
### Key Enhancements from Original:

- **Simplified Configuration**: Removed over-engineered customization options
- **Leverage Existing Generators**: Builds on current Gen combinators and primitives
- **Name-Based Inference**: Smart inference from property names (email, price, etc.)
- **Business-Realistic Defaults**: Generates business-appropriate test data

<!-- chunk 10 -->
### Integration with Existing Codebase

```swift
// Leverages existing generators from current codebase:
extension Gen {
    static var email: Gen<String> { /* existing email generator */ }
    static var currency: Gen<Decimal> { /* existing currency generator */ }
    static var age: Gen<Int> { /* existing age generator */ }
}

// Generated:
extension User: SmartGeneratable {
    static var smartGen: Gen<User> {
        Gen.zip4(
            Gen.uuid,              // id: UUID
            Gen.firstName,         // firstName: String  
            Gen.email,             // email: String
            Gen.age                // age: Int
        ).map(User.init)
    }
}
```

<!-- chunk 11 -->
### ✅ HIGH PRIORITY

<!-- Empty section ✅ HIGH PRIORITY -->

<!-- chunk 12 -->
### 3. `@TestAllCases` Macro

**Business Value**: Systematic boundary testing without test design expertise  
**Implementation Complexity**: Medium-High  
**Integration Points**: Extends existing Generator system

<!-- chunk 13 -->
### Enhanced Design (Simplified)

```swift
@attached(member, names: arbitrary)
@attached(extension, conformances: AutoTestable)
public macro TestAllCases(
    focus: TestFocus = .comprehensive
) = #externalMacro(module: "FunctionalTestingMacros", type: "TestAllCasesMacro")
```

<!-- chunk 14 -->
### Key Enhancements from Original:

- **Removed Complexity**: Eliminated over-engineered configuration options
- **Focus on Value**: Concentrates on boundary testing and edge cases
- **Existing Infrastructure**: Uses current Generator composition patterns

<!-- chunk 15 -->
### Implementation Strategy

<!-- Empty section Implementation Strategy -->

<!-- chunk 16 -->
### Sprint 1: Foundation (Week 1-2)

- [ ] Implement `@BusinessRule` macro core functionality
- [ ] Create BusinessRuleViolation error reporting system
- [ ] Integrate with existing Property/PropertyRunner infrastructure
- [ ] Add Swift Testing @Test generation

<!-- chunk 17 -->
### Sprint 2: Smart Generation (Week 3-4)

- [ ] Implement `@SmartGenerator` macro
- [ ] Create name-based inference system using existing patterns
- [ ] Extend current Gen system with business domain generators
- [ ] Add SmartGeneratable protocol

<!-- chunk 18 -->
### Sprint 3: Comprehensive Testing (Week 5-6)

- [ ] Implement `@TestAllCases` macro
- [ ] Create AutoTestSuite infrastructure
- [ ] Add boundary value testing using existing generators
- [ ] Polish and integration testing

<!-- chunk 19 -->
### Integration Points with Existing Codebase

<!-- Empty section Integration Points with Existing Codebase -->

<!-- chunk 20 -->
### Leveraged Infrastructure

- **Property<T>**: Core property testing infrastructure
- **Gen<T>**: Generator system and combinators
- **PropertyRunner**: Test execution engine
- **PropertyConfig**: Configuration system
- **Shrink<T>**: Input minimization for debugging

<!-- chunk 21 -->
### Enhanced Components

<!-- Empty section Enhanced Components -->

<!-- chunk 22 -->
### BusinessRuleViolation - Business-Friendly Error Reporting

```swift
/// Business-friendly error reporting for property test failures
/// 
/// Transforms mathematical counterexamples into actionable business insights,
/// bridging the gap between formal property testing and practical business understanding.
///
/// **Mathematical Foundation**:
/// Based on counterexample-guided abstraction refinement (CEGAR) principles,
/// providing minimal failing examples while maintaining business semantics.
///
/// **External References**:
/// - [Counterexample-Guided Abstraction Refinement](https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement)
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
public struct BusinessRuleViolation: Error, @unchecked Sendable {
    /// The business rule that was violated
    public let rule: String
    
    /// The minimal counterexample that violates the rule
    public let counterexample: Any
    
    /// The shrunk counterexample for debugging
    public let shrunk: Any
    
    /// Business impact description
    public let businessImpact: String
    
    /// Suggested remediation actions
    public let remediation: [String]
    
    /// Number of iterations before failure
    public let iterations: Int
    
    /// Severity level for business stakeholders
    public let severity: BusinessImpactSeverity
    
    public init(
        rule: String,
        counterexample: Any,
        shrunk: Any,
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

/// Business impact severity levels
public enum BusinessImpactSeverity: String, Sendable, CaseIterable {
    case critical = "Critical - Immediate business risk"
    case high = "High - Significant business impact"
    case medium = "Medium - Moderate business concern"
    case low = "Low - Minor business consideration"
}
```

<!-- chunk 23 -->
### SmartGeneratable - Protocol for Automatic Generator Derivation

```swift
/// Protocol for automatic generator derivation based on type structure and naming
/// 
/// Enables automatic generation of realistic test data based on property names,
/// types, and business domain conventions. Implements type-directed generation
/// with semantic inference capabilities.
///
/// **Mathematical Foundation**:
/// Based on dependent type theory and semantic analysis, where generator selection
/// depends on both static type information and semantic context from naming patterns.
///
/// **Laws**:
/// 1. **Consistency**: `T.smartGen.generate()` must produce valid instances of `T`
/// 2. **Coverage**: Generated values should cover practical business value ranges
/// 3. **Shrinking**: Generated values must shrink to simpler business-meaningful values
///
/// **External References**:
/// - [Dependent Type Theory](https://en.wikipedia.org/wiki/Dependent_type)
/// - [Semantic Analysis](https://en.wikipedia.org/wiki/Semantic_analysis_(compilers))
/// - [Type-Directed Programming](https://en.wikipedia.org/wiki/Type_system#Type-directed_programming)
public protocol SmartGeneratable {
    /// Automatically derived generator for this type
    /// 
    /// The generator produces business-realistic values that cover edge cases
    /// and common patterns for the domain while maintaining mathematical rigor.
    static var smartGen: Gen<Self> { get }
}

/// Generator constraints for controlling smart generation behavior
public struct GeneratorConstraints: Sendable {
    public let minValue: Double?
    public let maxValue: Double?
    public let allowNull: Bool
    public let businessRealistic: Bool
    public let edgeCaseProbability: Double
    
    public init(
        minValue: Double? = nil,
        maxValue: Double? = nil,
        allowNull: Bool = true,
        businessRealistic: Bool = true,
        edgeCaseProbability: Double = 0.1
    ) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.allowNull = allowNull
        self.businessRealistic = businessRealistic
        self.edgeCaseProbability = edgeCaseProbability
    }
    
    public static let realistic = GeneratorConstraints(businessRealistic: true)
    public static let comprehensive = GeneratorConstraints(
        businessRealistic: false,
        edgeCaseProbability: 0.3
    )
}
```

<!-- chunk 24 -->
### AutoTestable - Protocol for Comprehensive Testing

```swift
/// Protocol for automatic comprehensive test case generation
/// 
/// Enables systematic boundary testing and edge case coverage without requiring
/// deep testing expertise from developers.
///
/// **Mathematical Foundation**:
/// Based on boundary value analysis and equivalence partitioning theory,
/// systematically covering input domains and boundary conditions.
///
/// **External References**:
/// - [Boundary Value Analysis](https://en.wikipedia.org/wiki/Boundary_value_analysis)
/// - [Equivalence Partitioning](https://en.wikipedia.org/wiki/Equivalence_partitioning)
public protocol AutoTestable {
    /// Generate comprehensive test cases for this type
    static var comprehensiveTests: [Gen<Self>] { get }
    
    /// Generate boundary value test cases
    static var boundaryTests: [Gen<Self>] { get }
    
    /// Generate edge case test scenarios
    static var edgeCaseTests: [Gen<Self>] { get }
}
```

<!-- chunk 25 -->
### ComplexityAnalyzer - Smart Iteration Calculation

```swift
/// Analyzes function complexity to determine appropriate test iteration counts
/// 
/// Uses static analysis heuristics and empirical complexity scoring to recommend
/// iteration counts that balance thoroughness with execution time.
///
/// **Mathematical Foundation**:
/// Based on computational complexity theory and empirical analysis of
/// property testing effectiveness vs iteration count relationships.
///
/// **External References**:
/// - [Computational Complexity Theory](https://en.wikipedia.org/wiki/Computational_complexity_theory)
/// - [Cyclomatic Complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
public struct ComplexityAnalyzer: Sendable {
    /// Complexity scoring for functions and parameter types
    public struct ComplexityScore: Sendable {
        public let parameterComplexity: Int
        public let bodyComplexity: Int
        public let riskFactor: Double
        
        public var totalComplexity: Int {
            Int(Double(parameterComplexity + bodyComplexity) * riskFactor)
        }
    }
    
    /// Recommend iteration count based on complexity analysis
    public static func recommendIterations(for complexity: ComplexityScore) -> Int {
        let baseIterations = max(50, complexity.totalComplexity * 10)
        return min(baseIterations, 2000) // Cap at 2000 for performance
    }
    
    /// Calculate base iterations before risk adjustment
    public static func baseIterations(for complexity: ComplexityScore) -> Int {
        complexity.parameterComplexity * 25 + complexity.bodyComplexity * 10
    }
    
    /// Analyze function complexity from parameter types and names
    public static func analyzeFunction(
        parameterTypes: [String],
        parameterNames: [String],
        bodyComplexity: Int = 1
    ) -> ComplexityScore {
        let paramComplexity = parameterTypes.count + 
            parameterNames.reduce(0) { $0 + riskScore(for: $1) }
        
        return ComplexityScore(
            parameterComplexity: paramComplexity,
            bodyComplexity: bodyComplexity,
            riskFactor: calculateRiskFactor(parameterNames: parameterNames)
        )
    }
    
    private static func riskScore(for name: String) -> Int {
        let highRiskKeywords = ["price", "amount", "balance", "rate", "percent"]
        return highRiskKeywords.contains { name.lowercased().contains($0) } ? 2 : 0
    }
    
    private static func calculateRiskFactor(parameterNames: [String]) -> Double {
        let hasFinancialTerms = parameterNames.contains { name in
            ["price", "amount", "money", "currency", "rate"].contains { name.lowercased().contains($0) }
        }
        return hasFinancialTerms ? 1.5 : 1.0
    }
}
```

<!-- chunk 26 -->
### Success Criteria

<!-- Empty section Success Criteria -->

<!-- chunk 27 -->
### Technical Requirements

- [ ] Seamless integration with existing FunctionalTesting infrastructure
- [ ] Generated tests use @Test attribute for Swift Testing compatibility
- [ ] Performance comparable to hand-written property tests
- [ ] Compilation time impact < 20% for typical projects

<!-- chunk 28 -->
### Business Requirements

- [ ] New developers productive with business rules within 30 minutes
- [ ] Clear error messages that non-experts can understand
- [ ] Real-world business scenarios validate correctly

<!-- chunk 29 -->
### Mathematical Foundations (Hidden from Users)

While users don't need to understand these concepts, the implementation leverages:

- **Property-Based Testing**: ∀ x ∈ Domain, P(x) = true
- **Generator Composition**: Functor laws for Gen<T> mapping
- **Shrinking**: Minimal counterexample discovery through tree traversal
- **Complexity Analysis**: Input size → iteration count mapping

These mathematical foundations ensure correctness while being completely hidden behind business-friendly APIs.

<!-- chunk 30 -->
### Documentation Standards and Requirements

<!-- Empty section Documentation Standards and Requirements -->

<!-- chunk 31 -->
### DocC Documentation Requirements

All public APIs must include comprehensive DocC documentation following these patterns:

<!-- chunk 32 -->
### Example: Business Rule Documentation Template

```swift
/// **Business Rule Validation for E-commerce Systems**
/// 
/// Validates business rules using property-based testing with automatic
/// counterexample generation and business-friendly error reporting.
///
/// **Mathematical Foundation**:
/// Based on property-based testing theory where ∀ x ∈ Domain, P(x) = true.
/// Uses QuickCheck-style generators with shrinking for minimal counterexamples.
///
/// **Usage Examples**:
/// ```swift
/// @BusinessRule("Customer discount should not exceed item price")
/// func validateDiscount(item: Item, discount: Discount) -> Bool {
///     return discount.amount <= item.price
/// }
/// 
/// @BusinessRule("Order total should equal sum of item prices")
/// func validateOrderTotal(order: Order) -> Bool {
///     return order.total == order.items.map(\.price).reduce(0, +)
/// }
/// ```
///
/// **Business Impact**:
/// Prevents invalid discounts that could lead to financial loss,
/// ensures data integrity in order processing systems.
///
/// **Performance Characteristics**:
/// - Typical execution: 50-2000 iterations based on complexity
/// - Memory usage: O(1) per iteration with lazy evaluation
/// - Parallel execution: Safe with Swift 6 actor isolation
///
/// **External References**:
/// - [QuickCheck: A Lightweight Tool for Random Testing](https://dl.acm.org/doi/10.1145/351240.351266)
/// - [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
/// - [Counterexample-Guided Abstraction Refinement](https://en.wikipedia.org/wiki/Counterexample-guided_abstraction_refinement)
```

<!-- chunk 33 -->
### Documentation Deliverables

<!-- Empty section Documentation Deliverables -->

<!-- chunk 34 -->
### User Guides (30-minute onboarding target)

1. **Getting Started with Business Rules**
   - Zero-to-productive in 30 minutes
   - Real-world e-commerce examples
   - Common pitfalls and solutions
   - Integration with existing test suites

2. **Smart Test Data Generation Guide**
   - Automatic generator derivation
   - Customizing business constraints
   - Performance optimization tips
   - Debugging generated data

3. **Migrating from Manual Testing to Property Testing**
   - Identifying property test candidates
   - Converting existing tests
   - Measuring property test effectiveness
   - Gradual adoption strategies

<!-- chunk 35 -->
### Real-World Business Examples

1. **E-commerce Validation Scenarios**
```swift
@BusinessRule("Shopping cart total matches item sum")
func validateCartTotal(cart: ShoppingCart) -> Bool {
    let itemTotal = cart.items.map { $0.price * Decimal($0.quantity) }.reduce(0, +)
    return abs(cart.total - itemTotal) < 0.01
}

@BusinessRule("Coupon discounts cannot exceed cart value")
func validateCouponDiscount(cart: ShoppingCart, coupon: Coupon) -> Bool {
    return coupon.discountAmount <= cart.subtotal
}
```

2. **Financial Calculation Verification**
```swift
@BusinessRule("Compound interest calculation accuracy")
func validateCompoundInterest(
    principal: Decimal, 
    rate: Decimal, 
    periods: Int
) -> Bool {
    let calculated = calculateCompoundInterest(principal, rate, periods)
    let expected = principal * pow(1 + rate, Decimal(periods))
    return abs(calculated - expected) < 0.01
}

@BusinessRule("Loan payment covers interest and principal")
func validateLoanPayment(loan: Loan, payment: Payment) -> Bool {
    let monthlyInterest = loan.principal * loan.interestRate / 12
    return payment.amount >= monthlyInterest
}
```

3. **User Input Validation Scenarios**
```swift
@BusinessRule("Email addresses must be valid and unique")
func validateUserEmail(email: String, existingUsers: [User]) -> Bool {
    return Email.isValid(email) && !existingUsers.contains { $0.email == email }
}

@BusinessRule("Password meets security requirements")
func validatePassword(password: String) -> Bool {
    return password.count >= 8 && 
           password.contains { $0.isUppercase } &&
           password.contains { $0.isNumber } &&
           password.contains { "!@#$%^&*".contains($0) }
}
```

4. **Order Processing Business Rules**
```swift
@BusinessRule("Order status transitions are valid")
func validateOrderStatusTransition(from: OrderStatus, to: OrderStatus) -> Bool {
    let validTransitions: [OrderStatus: [OrderStatus]] = [
        .pending: [.confirmed, .cancelled],
        .confirmed: [.processing, .cancelled],
        .processing: [.shipped, .cancelled],
        .shipped: [.delivered, .returned],
        .delivered: [.returned],
        .cancelled: [],
        .returned: []
    ]
    return validTransitions[from]?.contains(to) ?? false
}

@BusinessRule("Inventory levels remain non-negative after order")
func validateInventoryAfterOrder(item: InventoryItem, orderQuantity: Int) -> Bool {
    return item.availableQuantity >= orderQuantity
}
```

<!-- chunk 36 -->
### Implementation Quality Gates

<!-- Empty section Implementation Quality Gates -->

<!-- chunk 37 -->
### Code Review Checklist

- [ ] All public APIs have DocC documentation with mathematical foundations
- [ ] Business examples included for all macros
- [ ] External references provided for complex concepts
- [ ] Generated code follows Swift 6 concurrency guidelines
- [ ] Error messages are business-friendly and actionable
- [ ] Performance impact is documented and measured

<!-- chunk 38 -->
### Documentation Quality Standards

- [ ] 30-minute onboarding achievable for new developers
- [ ] Mathematical concepts explained with Wikipedia references
- [ ] Business impact clearly articulated
- [ ] Troubleshooting guidance provided
- [ ] Examples are copy-pasteable and working

This enhanced specification provides a comprehensive foundation for implementing business-friendly property testing macros while maintaining mathematical rigor and achieving production-ready quality standards.
