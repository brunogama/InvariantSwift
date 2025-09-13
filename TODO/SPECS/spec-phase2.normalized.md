# Phase 2: Advanced Workflow Testing - Enhanced Specification

> Normalized on 2025-09-13T22:29:32Z using spec.template.md

## Title

Phase 2: Advanced Workflow Testing - Enhanced Specification

## Executive Summary

<!-- chunk 1 -->
### Executive Summary

This enhanced specification addresses critical gaps in the original Phase 2 document, providing comprehensive implementation guidance for advanced workflow testing capabilities. The specification builds upon the established Phase 1 foundation while ensuring production-readiness for complex business applications.

**Enhancement Areas Addressed:**
- Complete integration patterns with existing infrastructure
- Detailed error handling and recovery mechanisms
- Comprehensive testing and validation strategies
- Performance optimization guidelines
- Mathematical foundations documentation
- Migration and deployment strategies

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

- [ ] **Complete Invariant Testing**: Auto-generate comprehensive invariant validation
- [ ] **Workflow State Validation**: Complete state machine correctness testing
- [ ] **Business Error Reporting**: Clear, actionable error messages for stakeholders
- [ ] **Seamless Integration**: Works with existing Property/Gen/PropertyRunner infrastructure

## Non-Functional Requirements

_TBD_

## Architecture Overview

_TBD_

## System Components

_TBD_

## Data Model

_TBD_

## APIs and Contracts

_TBD_

## Workflows and Sequence Diagrams

_TBD_

## State Management and Concurrency

<!-- chunk 1 -->
### State Machine Theory

- **Formal Automata**: 5-tuple definition with business process mapping
- **Reachability Analysis**: Path validation using graph algorithms
- **Bisimulation**: Equivalence checking for workflow correctness

## Security and Compliance

_TBD_

## Performance and Capacity

<!-- chunk 1 -->
### Performance and Scaling Considerations

<!-- Empty section Performance and Scaling Considerations -->

<!-- chunk 2 -->
### Performance Targets

- **Compilation Impact**: <20% increase in compilation time
- **Runtime Performance**: Linear scaling with number of invariants/states
- **Memory Usage**: Bounded growth for large state spaces
- **Test Execution**: Parallel execution where safe

## Observability and Telemetry

_TBD_

## Error Handling and Resilience

_TBD_

## Testing Strategy

<!-- chunk 1 -->
### Testing and Validation Strategy

<!-- Empty section Testing and Validation Strategy -->

<!-- chunk 2 -->
### Property-Based Testing Mathematics

- **Universal Quantification**: ∀x ∈ Domain: P(x) holds
- **Counterexample Minimization**: Shrinking based on partial ordering
- **Coverage Metrics**: Branch and path coverage using formal definitions

## Release Plan and Migration

<!-- chunk 1 -->
### Migration and Deployment

<!-- Empty section Migration and Deployment -->

<!-- chunk 2 -->
### Migration Path

1. **Phase 1**: Deploy alongside existing testing (no disruption)
2. **Phase 2**: Migrate high-value use cases to new macros
3. **Phase 3**: Comprehensive migration with training
4. **Phase 4**: Deprecate manual invariant testing patterns

## Risks and Mitigations

_TBD_

## Assumptions and Constraints

_TBD_

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
### Current Architecture Assessment

<!-- Empty section Current Architecture Assessment -->

<!-- chunk 2 -->
### Existing Infrastructure Strengths

- **Robust Core**: Property<T>, Gen<T>, and PropertyRunner provide solid foundation
- **Coverage System**: Advanced coverage-guided testing with LLVM integration
- **Model-Based Testing**: Complete state machine testing framework available
- **Concurrency**: Full Swift 6 actor isolation compliance
- **Extensibility**: Well-designed protocol-witness patterns support expansion

<!-- chunk 3 -->
### Identified Gaps in Original Specification

1. **Missing Integration Patterns**: How new macros leverage existing systems
2. **Incomplete Error Handling**: Business-friendly error reporting needs specification
3. **Performance Considerations**: No guidance on scaling and optimization
4. **Testing Strategy**: Insufficient detail on validation approaches
5. **Migration Path**: No clear upgrade path for existing implementations
6. **Documentation Standards**: Mathematical concepts need better explanation

<!-- chunk 4 -->
### Enhanced Macro Specifications

<!-- Empty section Enhanced Macro Specifications -->

<!-- chunk 5 -->
### ✅ CRITICAL PRIORITY

<!-- Empty section ✅ CRITICAL PRIORITY -->

<!-- chunk 6 -->
### 1. `@ValidateInvariants` Macro - Enhanced Implementation

**Mathematical Foundation**: Based on invariant theory and algebraic data type properties
**Integration Pattern**: Protocol-witness pattern with existing Property system
**Performance Target**: O(n) where n = number of operations, linear scaling

<!-- chunk 7 -->
### Complete API Design

```swift
// MARK: - Core Invariant System

/// Marks types for automatic invariant validation testing
/// 
/// Generates comprehensive test suites that validate invariants across
/// all state-modifying operations using property-based testing methodology.
/// Based on algebraic invariant theory while hiding mathematical complexity.
///
/// ## Mathematical Foundation
/// 
/// This macro implements invariant validation based on the mathematical concept
/// of type invariants from formal verification. An invariant I is a predicate
/// that must hold for all valid states S of a type T:
///
/// ∀s ∈ S: I(s) = true
///
/// For operations O that transform states (s₁ →ᴼ s₂), invariants must be preserved:
///
/// I(s₁) ∧ valid(O, s₁) ⟹ I(s₂)
///
/// ## Implementation Strategy
///
/// 1. **Static Analysis**: Detect all state-modifying methods via Swift AST
/// 2. **Operation Generation**: Create property-based test operations 
/// 3. **Invariant Composition**: Combine multiple invariants with logical AND
/// 4. **Shrinking Strategy**: Use existing shrinking for minimal counterexamples
///
/// ## Business Value
///
/// - Eliminates manual invariant testing across complex state transitions
/// - Provides immediate feedback on business rule violations
/// - Generates comprehensive test coverage without mathematical knowledge
/// - Integrates with existing CI/CD pipelines through Swift Testing
///
/// ## Performance Characteristics
///
/// - Generation: O(1) per test case
/// - Validation: O(k×n) where k=invariants, n=operations
/// - Memory: O(n) for operation sequence storage
/// - Shrinking: O(log n) average case for binary search shrinking
///
@attached(member, names: arbitrary)
@attached(extension, conformances: InvariantTestable, InvariantValidatable)
public macro ValidateInvariants(
    /// Strategy for invariant validation testing
    strategy: InvariantStrategy = .comprehensive,
    /// Specific operations to test (auto-detect if empty)
    operations: [String] = [],
    /// Maximum operation sequence length for testing
    maxOperations: Int = 20,
    /// Custom test configurations
    config: InvariantConfig = .default
) = #externalMacro(module: "FunctionalTestingMacros", type: "ValidateInvariantsMacro")

/// Individual invariant declaration with business description
///
/// Marks individual invariant predicates for inclusion in validation testing.
/// Each invariant represents a business rule that must hold across all valid states.
///
/// ## Usage Pattern
///
/// ```swift
/// @ValidateInvariants
/// class BankAccount {
///     private var balance: Decimal = 0
///     private var isActive: Bool = true
///     
///     @Invariant("Account balance must be non-negative for standard accounts")
///     var balanceInvariant: Bool { 
///         accountType == .premium || balance >= 0 
///     }
///     
///     @Invariant("Active accounts must have valid balance tracking")
///     var activeAccountInvariant: Bool {
///         !isActive || balance != .nan
///     }
/// }
/// ```
///
@attached(peer, names: suffixed(_InvariantTest))
public macro Invariant(
    /// Business-friendly description of the invariant
    _ description: String,
    /// Priority level for test execution ordering
    priority: InvariantPriority = .normal,
    /// Enable/disable this specific invariant
    enabled: Bool = true
) = #externalMacro(module: "FunctionalTestingMacros", type: "InvariantMacro")

/// Configuration for invariant validation testing
public struct InvariantConfig: Sendable {
    /// Number of test iterations per invariant
    public let iterations: Int
    /// Maximum shrinking attempts for counterexamples
    public let maxShrinks: Int
    /// Timeout for individual test runs
    public let timeout: TimeInterval
    /// Enable parallel testing of invariants
    public let enableParallelTesting: Bool
    /// Coverage tracking for invariant validation
    public let enableCoverageTracking: Bool
    
    public init(
        iterations: Int = 100,
        maxShrinks: Int = 1000,
        timeout: TimeInterval = 30.0,
        enableParallelTesting: Bool = true,
        enableCoverageTracking: Bool = true
    ) {
        self.iterations = max(1, iterations)
        self.maxShrinks = max(0, maxShrinks)
        self.timeout = max(1.0, timeout)
        self.enableParallelTesting = enableParallelTesting
        self.enableCoverageTracking = enableCoverageTracking
    }
    
    public static let `default` = InvariantConfig()
    public static let quick = InvariantConfig(iterations: 10, maxShrinks: 100)
    public static let thorough = InvariantConfig(iterations: 1000, maxShrinks: 5000)
}

/// Testing strategies for invariant validation
public enum InvariantStrategy: Sendable, CaseIterable {
    /// Comprehensive testing of all operation combinations
    case comprehensive
    /// Focus on boundary conditions and edge cases  
    case boundary
    /// Random sampling approach for large state spaces
    case sampling
    /// Coverage-guided testing to maximize code path exploration
    case coverageGuided
    /// Adaptive strategy that adjusts based on findings
    case adaptive
    
    /// Recommended configuration for this strategy
    public var recommendedConfig: InvariantConfig {
        switch self {
        case .comprehensive:
            return .thorough
        case .boundary:
            return InvariantConfig(iterations: 200, enableCoverageTracking: true)
        case .sampling:
            return .default
        case .coverageGuided:
            return InvariantConfig(iterations: 500, enableCoverageTracking: true)
        case .adaptive:
            return .default
        }
    }
}

/// Priority levels for invariant testing
public enum InvariantPriority: Int, Sendable, CaseIterable {
    /// Critical business invariants - test first
    case critical = 0
    /// High priority invariants - test early
    case high = 1
    /// Normal priority invariants
    case normal = 2
    /// Low priority invariants - test last
    case low = 3
    
    public var description: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"  
        case .normal: return "Normal"
        case .low: return "Low"
        }
    }
}
```

<!-- chunk 8 -->
### Enhanced Error Reporting System

```swift
// MARK: - Business-Friendly Error Reporting

/// Comprehensive error type for invariant violations with business context
public struct InvariantViolation: Error, CustomStringConvertible, Sendable {
    /// Business description of the violated invariant
    public let invariantDescription: String
    /// The object state that violated the invariant
    public let violatingState: Any
    /// Sequence of operations that led to violation
    public let operationSequence: [String]
    /// Minimal counterexample after shrinking
    public let shrunkCounterexample: Any
    /// Business impact assessment
    public let businessImpact: String
    /// Suggested remediation steps
    public let suggestedFix: String
    /// Timestamp of violation
    public let timestamp: Date
    /// Additional context for debugging
    public let debugContext: [String: Any]
    
    public init(
        invariantDescription: String,
        violatingState: Any,
        operationSequence: [String],
        shrunkCounterexample: Any,
        businessImpact: String,
        suggestedFix: String = "Review business logic for edge cases",
        timestamp: Date = Date(),
        debugContext: [String: Any] = [:]
    ) {
        self.invariantDescription = invariantDescription
        self.violatingState = violatingState
        self.operationSequence = operationSequence
        self.shrunkCounterexample = shrunkCounterexample
        self.businessImpact = businessImpact
        self.suggestedFix = suggestedFix
        self.timestamp = timestamp
        self.debugContext = debugContext
    }
    
    public var description: String {
        """
        ❌ BUSINESS INVARIANT VIOLATION
        
        Rule: \(invariantDescription)
        Impact: \(businessImpact)
        
        📊 VIOLATION DETAILS:
        - Timestamp: \(timestamp.ISO8601Format())
        - Operation Sequence: \(operationSequence.joined(separator: " → "))
        - Violating State: \(String(describing: violatingState))
        - Minimal Example: \(String(describing: shrunkCounterexample))
        
        🔧 SUGGESTED FIX:
        \(suggestedFix)
        
        🐛 DEBUG CONTEXT:
        \(debugContext.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
        """
    }
    
    /// Generate business report suitable for stakeholders
    public func businessReport() -> String {
        """
        BUSINESS RULE VIOLATION REPORT
        
        Rule: \(invariantDescription)
        Business Impact: \(businessImpact)
        Occurred: \(timestamp.formatted(date: .abbreviated, time: .shortened))
        
        The system detected a violation of business rules during automated testing.
        This indicates a potential issue that could affect customers or business operations.
        
        Recommended Action: \(suggestedFix)
        """
    }
}

/// Protocol for types that support invariant validation
public protocol InvariantTestable {
    /// All invariants defined for this type
    static var invariants: [InvariantDefinition] { get }
    /// Validate all invariants for the current instance
    func validateAllInvariants() throws
}

/// Protocol for types that can validate specific invariants
public protocol InvariantValidatable {
    /// Validate a specific invariant by name
    func validateInvariant(_ name: String) throws -> Bool
    /// Get all operation names that modify state
    static var stateModifyingOperations: [String] { get }
}

/// Definition of an individual invariant with metadata
public struct InvariantDefinition: Sendable {
    public let name: String
    public let description: String
    public let priority: InvariantPriority
    public let predicate: @Sendable (Any) -> Bool
    public let enabled: Bool
    
    public init(
        name: String,
        description: String, 
        priority: InvariantPriority = .normal,
        predicate: @escaping @Sendable (Any) -> Bool,
        enabled: Bool = true
    ) {
        self.name = name
        self.description = description
        self.priority = priority
        self.predicate = predicate
        self.enabled = enabled
    }
}
```

<!-- chunk 9 -->
### Complete Generated Code Pattern

```swift
// MARK: - Example Generated Implementation

// Input:
@ValidateInvariants(strategy: .comprehensive)
class BankAccount {
    private var balance: Decimal = 0
    private var accountType: AccountType = .standard
    private var isActive: Bool = true
    
    @Invariant("Balance should never be negative for standard accounts", priority: .critical)
    var balanceInvariant: Bool { 
        accountType == .premium || balance >= 0 
    }
    
    @Invariant("Active accounts must have valid balance tracking")
    var activeAccountInvariant: Bool {
        !isActive || !balance.isNaN
    }
    
    func deposit(_ amount: Decimal) {
        balance += amount
    }
    
    func withdraw(_ amount: Decimal) throws {
        guard balance >= amount else { throw InsufficientFundsError() }
        balance -= amount
    }
    
    func close() {
        isActive = false
    }
}

// Generated (using existing infrastructure):
extension BankAccount: InvariantTestable, InvariantValidatable {
    static var invariants: [InvariantDefinition] {
        [
            InvariantDefinition(
                name: "balanceInvariant",
                description: "Balance should never be negative for standard accounts",
                priority: .critical,
                predicate: { account in
                    guard let acc = account as? BankAccount else { return false }
                    return acc.balanceInvariant
                }
            ),
            InvariantDefinition(
                name: "activeAccountInvariant", 
                description: "Active accounts must have valid balance tracking",
                priority: .normal,
                predicate: { account in
                    guard let acc = account as? BankAccount else { return false }
                    return acc.activeAccountInvariant
                }
            )
        ]
    }
    
    static var stateModifyingOperations: [String] {
        ["deposit", "withdraw", "close"]
    }
    
    func validateAllInvariants() throws {
        for invariant in Self.invariants where invariant.enabled {
            guard invariant.predicate(self) else {
                throw InvariantViolation(
                    invariantDescription: invariant.description,
                    violatingState: self,
                    operationSequence: [], // Will be populated during testing
                    shrunkCounterexample: self,
                    businessImpact: self.assessBusinessImpact(for: invariant.name)
                )
            }
        }
    }
    
    func validateInvariant(_ name: String) throws -> Bool {
        guard let invariant = Self.invariants.first(where: { $0.name == name }) else {
            throw InvariantValidationError.unknownInvariant(name)
        }
        return invariant.predicate(self)
    }
    
    @Test("BankAccount Invariants - Comprehensive Strategy") 
    func testInvariants_Comprehensive() async throws {
        let config = InvariantStrategy.comprehensive.recommendedConfig
        
        // Create operation generator that respects business constraints
        let operationGen = Gen<BankAccountOperation>.frequency([
            (3, .deposit(Gen.decimal(in: 0.01...1000.0))),
            (2, .withdraw(Gen.decimal(in: 0.01...500.0))), 
            (1, .close)
        ])
        
        let property = Property<(BankAccount, [BankAccountOperation])>(
            generator: Gen.zip(
                BankAccount.validInstanceGen,
                Gen.array(operationGen, count: 1...config.maxOperations)
            ),
            predicate: { (account, operations) in
                var testAccount = account
                var operationHistory: [String] = []
                
                do {
                    for operation in operations {
                        // Record operation for error reporting
                        operationHistory.append(operation.description)
                        
                        // Apply operation with proper error handling
                        try operation.apply(to: &testAccount)
                        
                        // Validate all invariants after each operation
                        try testAccount.validateAllInvariants()
                    }
                    return true
                } catch is InvariantViolation {
                    // Let invariant violations propagate for proper error reporting
                    return false
                } catch {
                    // Business operations can fail legitimately (e.g., insufficient funds)
                    // This should not count as invariant violation
                    return true
                }
            }
        )
        
        let result: PropertyResult<(BankAccount, [BankAccountOperation])>
        
        if config.enableCoverageTracking {
            let (propResult, coverageReport) = await PropertyRunner().runPropertyWithCoverageTracking(
                property,
                knownSymbols: Set(Self.stateModifyingOperations),
                config: PropertyConfig(
                    iterations: config.iterations,
                    maxShrinks: config.maxShrinks
                )
            )
            result = propResult
            print("Coverage Report: \(coverageReport.summary())")
        } else {
            result = await PropertyRunner().runProperty(
                property, 
                config: PropertyConfig(
                    iterations: config.iterations,
                    maxShrinks: config.maxShrinks
                )
            )
        }
        
        if case .failure(let counterexample, let iterations, let shrunk) = result {
            throw InvariantViolation(
                invariantDescription: "One or more business invariants",
                violatingState: counterexample.0,
                operationSequence: counterexample.1.map(\.description),
                shrunkCounterexample: shrunk.0,
                businessImpact: "Customer accounts may enter invalid states, violating banking regulations and potentially causing financial loss",
                suggestedFix: "Review business logic in state-modifying operations for edge cases and boundary conditions",
                debugContext: [
                    "iterations": iterations,
                    "strategy": "comprehensive",
                    "operations_tested": counterexample.1.count
                ]
            )
        }
    }
    
    private func assessBusinessImpact(for invariantName: String) -> String {
        switch invariantName {
        case "balanceInvariant":
            return "Negative balances could violate banking regulations and cause customer disputes"
        case "activeAccountInvariant":
            return "Invalid balance tracking could lead to incorrect financial reporting"
        default:
            return "Business rule violation could impact system reliability and compliance"
        }
    }
}

// MARK: - Supporting Types for Generated Code

enum BankAccountOperation: CustomStringConvertible {
    case deposit(Decimal)
    case withdraw(Decimal)
    case close
    
    var description: String {
        switch self {
        case .deposit(let amount): return "deposit(\(amount))"
        case .withdraw(let amount): return "withdraw(\(amount))"
        case .close: return "close()"
        }
    }
    
    func apply(to account: inout BankAccount) throws {
        switch self {
        case .deposit(let amount):
            account.deposit(amount)
        case .withdraw(let amount):
            try account.withdraw(amount)
        case .close:
            account.close()
        }
    }
}

extension BankAccount {
    static var validInstanceGen: Gen<BankAccount> {
        Gen.zip(
            Gen.decimal(in: 0...10000),
            Gen.oneOf([AccountType.standard, .premium]),
            Gen.bool
        ).map { balance, type, isActive in
            let account = BankAccount()
            account.balance = balance
            account.accountType = type
            account.isActive = isActive
            return account
        }
    }
}

enum InvariantValidationError: Error {
    case unknownInvariant(String)
    case validationFailed(String)
}
```

<!-- chunk 10 -->
### 2. `@TestWorkflow` Macro - Enhanced Implementation

**Mathematical Foundation**: State machine theory and formal verification principles
**Integration Pattern**: Leverages existing enum generators and property testing
**Performance Target**: O(n²) where n = number of states, quadratic validation

<!-- chunk 11 -->
### Complete API Design

```swift
// MARK: - Workflow Testing System

/// Enables comprehensive workflow testing for state machine-like types
///
/// Generates property-based tests that validate state transition correctness,
/// business process compliance, and workflow invariants. Based on formal
/// state machine theory while presenting business-friendly interfaces.
///
/// ## Mathematical Foundation
///
/// This macro implements state machine testing based on formal automata theory.
/// A workflow W is defined as a 5-tuple (Q, Σ, δ, q₀, F) where:
/// - Q: Set of states
/// - Σ: Input alphabet (transitions)  
/// - δ: Transition function Q × Σ → Q
/// - q₀: Initial state
/// - F: Set of accepting/final states
///
/// The macro validates that:
/// 1. All transitions preserve workflow invariants
/// 2. Invalid transitions are properly rejected
/// 3. Business processes complete in valid end states
/// 4. State transition sequences satisfy business rules
///
/// ## Business Value
///
/// - Eliminates manual workflow testing across complex business processes
/// - Validates state machine correctness without formal methods knowledge
/// - Generates comprehensive test coverage for business workflows
/// - Provides clear error reporting for process violations
///
/// ## Performance Characteristics
///
/// - State validation: O(|Q|²) for complete transition matrix testing
/// - Path validation: O(k×n) where k=paths, n=average path length
/// - Memory usage: O(|Q|×|Σ|) for transition table storage
///
@attached(member, names: arbitrary)
@attached(extension, conformances: WorkflowTestable, WorkflowValidatable)
public macro TestWorkflow(
    /// Strategy for workflow testing
    strategy: WorkflowStrategy = .comprehensive,
    /// Enable transition validation (default: true)
    validateTransitions: Bool = true,
    /// Enable path validation (default: true) 
    validatePaths: Bool = true,
    /// Maximum path length for testing
    maxPathLength: Int = 10,
    /// Custom workflow configuration
    config: WorkflowConfig = .default
) = #externalMacro(module: "FunctionalTestingMacros", type: "TestWorkflowMacro")

/// Configuration for workflow testing
public struct WorkflowConfig: Sendable {
    /// Number of random paths to test per state
    public let pathsPerState: Int
    /// Maximum path length for exploration
    public let maxPathLength: Int
    /// Number of iterations for property testing
    public let iterations: Int  
    /// Enable coverage-guided path exploration
    public let enableCoverageGuided: Bool
    /// Timeout for individual workflow tests
    public let timeout: TimeInterval
    
    public init(
        pathsPerState: Int = 10,
        maxPathLength: Int = 10,
        iterations: Int = 100,
        enableCoverageGuided: Bool = true,
        timeout: TimeInterval = 30.0
    ) {
        self.pathsPerState = max(1, pathsPerState)
        self.maxPathLength = max(1, maxPathLength)
        self.iterations = max(1, iterations)
        self.enableCoverageGuided = enableCoverageGuided
        self.timeout = max(1.0, timeout)
    }
    
    public static let `default` = WorkflowConfig()
    public static let quick = WorkflowConfig(pathsPerState: 5, iterations: 20)
    public static let thorough = WorkflowConfig(pathsPerState: 20, maxPathLength: 20, iterations: 500)
}

/// Workflow testing strategies
public enum WorkflowStrategy: Sendable, CaseIterable {
    /// Test all possible state transitions
    case comprehensive
    /// Focus on business-critical paths
    case criticalPaths
    /// Random walk exploration
    case exploration
    /// Coverage-guided testing
    case coverageGuided
    /// Boundary condition focus
    case boundaries
    
    public var recommendedConfig: WorkflowConfig {
        switch self {
        case .comprehensive:
            return .thorough
        case .criticalPaths:
            return WorkflowConfig(pathsPerState: 15, enableCoverageGuided: true)
        case .exploration:
            return WorkflowConfig(pathsPerState: 20, maxPathLength: 15)
        case .coverageGuided:
            return WorkflowConfig(enableCoverageGuided: true)
        case .boundaries:
            return WorkflowConfig(pathsPerState: 8, maxPathLength: 5)
        }
    }
}

/// Business-friendly workflow error reporting
public struct WorkflowViolation: Error, CustomStringConvertible, Sendable {
    /// Description of the workflow being tested
    public let workflowDescription: String
    /// The invalid transition that was attempted
    public let invalidTransition: StateTransition
    /// Current workflow state when violation occurred
    public let currentState: Any
    /// Target state that was invalid
    public let targetState: Any
    /// Business process that was violated
    public let violatedProcess: String
    /// Business impact of the violation
    public let businessImpact: String
    /// Path taken to reach violation
    public let transitionPath: [StateTransition]
    /// Timestamp of violation
    public let timestamp: Date
    
    public init(
        workflowDescription: String,
        invalidTransition: StateTransition,
        currentState: Any,
        targetState: Any,
        violatedProcess: String,
        businessImpact: String,
        transitionPath: [StateTransition] = [],
        timestamp: Date = Date()
    ) {
        self.workflowDescription = workflowDescription
        self.invalidTransition = invalidTransition
        self.currentState = currentState
        self.targetState = targetState
        self.violatedProcess = violatedProcess
        self.businessImpact = businessImpact
        self.transitionPath = transitionPath
        self.timestamp = timestamp
    }
    
    public var description: String {
        let pathDescription = transitionPath.isEmpty ? "Direct transition" 
            : transitionPath.map(\.description).joined(separator: " → ")
            
        return """
        ❌ WORKFLOW VIOLATION
        
        Workflow: \(workflowDescription)
        Process: \(violatedProcess)
        Impact: \(businessImpact)
        
        📊 VIOLATION DETAILS:
        - Invalid Transition: \(invalidTransition.description)
        - Current State: \(String(describing: currentState))
        - Target State: \(String(describing: targetState))
        - Path: \(pathDescription)
        - Timestamp: \(timestamp.ISO8601Format())
        
        This violation indicates a business process constraint was not properly enforced.
        """
    }
}

/// Represents a state transition in a workflow
public struct StateTransition: CustomStringConvertible, Sendable {
    public let from: String
    public let to: String
    public let action: String?
    
    public init(from: String, to: String, action: String? = nil) {
        self.from = from
        self.to = to
        self.action = action
    }
    
    public var description: String {
        if let action = action {
            return "\(from) --[\(action)]--> \(to)"
        } else {
            return "\(from) --> \(to)"
        }
    }
}

/// Protocol for workflow testing capabilities
public protocol WorkflowTestable {
    /// All possible states in this workflow
    static var allStates: [String] { get }
    /// Valid transitions from each state
    static var validTransitions: [String: [String]] { get }
    /// Business processes supported by this workflow
    static var businessProcesses: [String] { get }
}

/// Protocol for workflow validation
public protocol WorkflowValidatable {
    /// Check if transition is valid in business context
    func canTransition(from: String, to: String) -> Bool
    /// Execute transition with business validation
    func performTransition(from: String, to: String) throws
    /// Validate current workflow state
    func validateCurrentState() throws
}
```

<!-- chunk 12 -->
### Complete Generated Code Example

```swift
// Input:
@TestWorkflow(strategy: .comprehensive)
enum OrderState: String, CaseIterable {
    case draft = "draft"
    case submitted = "submitted" 
    case approved = "approved"
    case paid = "paid"
    case shipped = "shipped"
    case delivered = "delivered"
    case cancelled = "cancelled"
    case returned = "returned"
    
    // Convention-based transition definitions
    static let validTransitions: [OrderState: [OrderState]] = [
        .draft: [.submitted, .cancelled],
        .submitted: [.approved, .cancelled], 
        .approved: [.paid, .cancelled],
        .paid: [.shipped, .cancelled],
        .shipped: [.delivered, .returned],
        .delivered: [.returned],
        .cancelled: [], // Terminal state
        .returned: []   // Terminal state  
    ]
    
    static let businessProcesses = [
        "Standard Order Flow",
        "Cancellation Process", 
        "Return Process"
    ]
}

// Generated implementation:
extension OrderState: WorkflowTestable, WorkflowValidatable {
    static var allStates: [String] {
        OrderState.allCases.map(\.rawValue)
    }
    
    static var validTransitions: [String: [String]] {
        Dictionary(
            OrderState.validTransitions.map { state, targets in
                (state.rawValue, targets.map(\.rawValue))
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
    
    func canTransition(from: String, to: String) -> Bool {
        guard let fromState = OrderState(rawValue: from),
              let toState = OrderState(rawValue: to) else {
            return false
        }
        
        return OrderState.validTransitions[fromState]?.contains(toState) ?? false
    }
    
    func performTransition(from: String, to: String) throws {
        guard canTransition(from: from, to: to) else {
            throw WorkflowViolation(
                workflowDescription: "Order Processing Workflow",
                invalidTransition: StateTransition(from: from, to: to),
                currentState: from,
                targetState: to,
                violatedProcess: "State transition validation",
                businessImpact: "Invalid order state transitions could corrupt order processing pipeline"
            )
        }
    }
    
    func validateCurrentState() throws {
        // Additional business validation logic can be added here
    }
    
    @Test("OrderState Workflow - Comprehensive Strategy")
    func testWorkflow_Comprehensive() async throws {
        let config = WorkflowStrategy.comprehensive.recommendedConfig
        
        // Test 1: Valid transition validation
        let transitionProperty = Property<(OrderState, OrderState)>(
            generator: Gen.zip(
                Gen.oneOf(OrderState.allCases),
                Gen.oneOf(OrderState.allCases)
            ),
            predicate: { (from, to) in
                let shouldBeValid = OrderState.validTransitions[from]?.contains(to) ?? false
                let actualResult = from.canTransition(from: from.rawValue, to: to.rawValue)
                return shouldBeValid == actualResult
            }
        )
        
        let transitionResult = await PropertyRunner().runProperty(
            transitionProperty,
            config: PropertyConfig(iterations: config.iterations)
        )
        
        if case .failure(let counterexample, _, _) = transitionResult {
            throw WorkflowViolation(
                workflowDescription: "Order State Transitions",
                invalidTransition: StateTransition(
                    from: counterexample.0.rawValue,
                    to: counterexample.1.rawValue
                ),
                currentState: counterexample.0,
                targetState: counterexample.1,
                violatedProcess: "Transition validation consistency",
                businessImpact: "Inconsistent transition validation could allow invalid order state changes"
            )
        }
        
        // Test 2: Path validation  
        let pathProperty = Property<[OrderState]>(
            generator: OrderWorkflowPathGenerator(maxLength: config.maxPathLength).asGen(),
            predicate: { path in
                guard path.count >= 2 else { return true }
                
                // Validate each transition in the path
                for i in 0..<(path.count - 1) {
                    let from = path[i]
                    let to = path[i + 1]
                    
                    if !from.canTransition(from: from.rawValue, to: to.rawValue) {
                        return false
                    }
                }
                return true
            }
        )
        
        let pathResult = await PropertyRunner().runProperty(
            pathProperty, 
            config: PropertyConfig(iterations: config.iterations)
        )
        
        if case .failure(let counterexample, _, let shrunk) = pathResult {
            let invalidPath = counterexample
            let transitions = zip(invalidPath.dropLast(), invalidPath.dropFirst())
                .map { StateTransition(from: $0.rawValue, to: $1.rawValue) }
                
            throw WorkflowViolation(
                workflowDescription: "Order Processing Path",
                invalidTransition: transitions.first ?? StateTransition(from: "unknown", to: "unknown"),
                currentState: invalidPath.first ?? OrderState.draft,
                targetState: invalidPath.last ?? OrderState.draft,
                violatedProcess: "Multi-step order processing",
                businessImpact: "Invalid order processing paths could lead to orders stuck in inconsistent states",
                transitionPath: transitions
            )
        }
    }
    
    @Test("OrderState Business Process Validation")
    func testBusinessProcesses() async throws {
        // Test critical business paths
        let standardFlow: [OrderState] = [.draft, .submitted, .approved, .paid, .shipped, .delivered]
        let cancellationFlow: [OrderState] = [.draft, .submitted, .cancelled]  
        let returnFlow: [OrderState] = [.draft, .submitted, .approved, .paid, .shipped, .delivered, .returned]
        
        for process in [standardFlow, cancellationFlow, returnFlow] {
            try await validateBusinessProcess(process)
        }
    }
    
    private func validateBusinessProcess(_ process: [OrderState]) async throws {
        for i in 0..<(process.count - 1) {
            let from = process[i]
            let to = process[i + 1]
            
            do {
                try from.performTransition(from: from.rawValue, to: to.rawValue)
            } catch {
                throw WorkflowViolation(
                    workflowDescription: "Business Process Validation",
                    invalidTransition: StateTransition(from: from.rawValue, to: to.rawValue),
                    currentState: from,
                    targetState: to, 
                    violatedProcess: "Critical business flow",
                    businessImpact: "Core business processes are failing validation, indicating systemic workflow issues"
                )
            }
        }
    }
}

/// Generator for valid workflow paths
struct OrderWorkflowPathGenerator {
    let maxLength: Int
    
    func asGen() -> Gen<[OrderState]> {
        Gen { rng, size in
            var path: [OrderState] = [.draft] // Always start with draft
            let targetLength = min(Int.random(in: 2...maxLength, using: &rng), size.value)
            
            while path.count < targetLength {
                let current = path.last!
                let validNextStates = OrderState.validTransitions[current] ?? []
                
                if validNextStates.isEmpty {
                    break // Reached terminal state
                }
                
                let next = validNextStates.randomElement(using: &rng)!
                path.append(next)
                
                // Avoid infinite loops in cyclic workflows
                if path.count > maxLength {
                    break
                }
            }
            
            return path
        }
    }
}
```

<!-- chunk 13 -->
### Implementation Strategy

<!-- Empty section Implementation Strategy -->

<!-- chunk 14 -->
### Sprint 1: Foundation and Integration (Week 1-2)

- [ ] **Core Infrastructure Setup**
  - Implement `InvariantTestable` and `WorkflowTestable` protocols
  - Create error reporting system with `InvariantViolation` and `WorkflowViolation`
  - Integrate with existing `Property<T>` and `Gen<T>` systems
  - Add configuration types (`InvariantConfig`, `WorkflowConfig`)

- [ ] **Basic Macro Implementations**
  - Implement `@ValidateInvariants` macro with AST analysis
  - Create operation detection system for state-modifying methods  
  - Implement `@Invariant` macro for individual invariant marking
  - Add basic code generation for invariant testing

- [ ] **Testing and Validation**
  - Create comprehensive test suite for macro expansions
  - Validate generated code compiles and executes correctly
  - Test error reporting mechanisms
  - Verify integration with existing Property testing system

<!-- chunk 15 -->
### Sprint 2: Advanced Features (Week 3-4)

- [ ] **Workflow Testing Implementation**
  - Implement `@TestWorkflow` macro with state machine analysis
  - Create transition validation system
  - Add path generation and validation capabilities
  - Implement business process testing

- [ ] **Performance Optimization**
  - Add coverage-guided testing integration
  - Implement parallel testing capabilities for invariants
  - Optimize macro expansion performance
  - Add memory usage monitoring for large state spaces

- [ ] **Enhanced Error Reporting**
  - Implement business impact assessment
  - Add suggested fix generation
  - Create stakeholder-friendly error reports
  - Integrate with existing telemetry system

<!-- chunk 16 -->
### Sprint 3: Integration and Polish (Week 5-6)

- [ ] **Production Integration**
  - Complete SwiftTesting integration
  - Add CLI support through FuncTestCLI
  - Implement SPM plugin integration
  - Create comprehensive documentation

- [ ] **Quality Assurance**
  - Achieve 99% code coverage requirement
  - Complete performance benchmarking
  - Validate against complex real-world scenarios
  - Security review for generated code

- [ ] **Documentation and Examples**
  - Complete DocC documentation with mathematical explanations
  - Create business-focused usage examples
  - Add migration guide from manual testing
  - Performance and scaling guidelines

<!-- chunk 17 -->
### Integration with Existing Codebase

<!-- Empty section Integration with Existing Codebase -->

<!-- chunk 18 -->
### Leveraged Infrastructure

- **Property<T>**: Core property testing from existing implementation
- **Gen<T>**: Generator system with functor/monad support
- **PropertyRunner**: Async test execution with coverage integration
- **CoverageGuided**: Advanced coverage tracking and reporting
- **ModelTesting**: State machine testing patterns for workflow validation
- **TelemetrySystem**: Error reporting and monitoring integration

<!-- chunk 19 -->
### New Components Added

- **InvariantTestable/WorkflowTestable**: Protocol-witness pattern for macro integration
- **Enhanced Error Reporting**: Business-friendly error types with context
- **Configuration System**: Comprehensive configuration for different testing strategies
- **Code Generation**: SwiftSyntax-based macro implementations with AST analysis

<!-- chunk 20 -->
### Scaling Guidelines

- **Small Workflows**: (<10 states) - Use comprehensive testing
- **Medium Workflows**: (10-50 states) - Use coverage-guided or sampling strategies
- **Large Workflows**: (>50 states) - Use boundary or critical path strategies
- **Performance Monitoring**: Integrate with existing telemetry system

<!-- chunk 21 -->
### Comprehensive Testing Approach

1. **Unit Tests**: Individual macro components and generated code
2. **Integration Tests**: End-to-end macro expansion and execution
3. **Performance Tests**: Scaling behavior and resource usage
4. **Business Scenario Tests**: Real-world business logic validation
5. **Error Path Tests**: Error handling and recovery mechanisms

<!-- chunk 22 -->
### Validation Criteria

- [ ] All generated code compiles without warnings
- [ ] Generated tests execute successfully in parallel
- [ ] Error messages are business-friendly and actionable
- [ ] Performance meets scaling requirements
- [ ] Integration with existing systems is seamless

<!-- chunk 23 -->
### Deployment Requirements

- **Swift 6.0+**: Required for strict concurrency compliance
- **SwiftSyntax**: 509.0.0 - 602.0.0 compatibility maintained
- **Platform Support**: iOS 16+, macOS 13+, consistent with existing package
- **CI/CD Integration**: Compatible with existing build and test pipelines

<!-- chunk 24 -->
### Mathematical Foundations (Implementation Reference)

<!-- Empty section Mathematical Foundations (Implementation Reference) -->

<!-- chunk 25 -->
### Invariant Theory Application

- **Algebraic Invariants**: Properties preserved under group actions (state transformations)
- **Type System Integration**: Swift's type system enforces invariant safety at compile time
- **Category Theory**: Functor and monad laws applied to generator composition

<!-- chunk 26 -->
### Success Criteria and Validation

<!-- Empty section Success Criteria and Validation -->

<!-- chunk 27 -->
### Technical Requirements

- [ ] **Performance**: <20% compilation overhead, linear runtime scaling  
- [ ] **Reliability**: 99%+ code coverage, comprehensive error handling
- [ ] **Maintainability**: Clear separation of concerns, documented mathematical foundations
- [ ] **Extensibility**: Support for custom strategies and configurations

<!-- chunk 28 -->
### Business Requirements

- [ ] **User Experience**: No mathematical knowledge required for usage
- [ ] **Actionable Results**: Business stakeholders can understand test failures
- [ ] **Development Velocity**: Reduces manual test writing by >80%
- [ ] **Risk Reduction**: Catches business rule violations before production

This enhanced specification provides comprehensive implementation guidance for Phase 2 Advanced Workflow Testing, addressing all identified gaps while maintaining alignment with the existing FunctionalTesting framework architecture and business requirements.
