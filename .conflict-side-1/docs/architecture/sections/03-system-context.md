# System Context

### 3.1 System Boundaries

```mermaid
C4Context
    title InvariantSwift System Context

    Person(dev, "Swift Developer", "Uses framework to write property tests")
    Person(ci, "CI/CD System", "Runs tests in automation")

    System(invariant, "InvariantSwift", "Property-based testing framework")

    System_Ext(swift, "Swift Compiler", "Compiles macros and validates concurrency")
    System_Ext(testing, "Swift Testing Framework", "Runs generated test functions")
    System_Ext(spm, "SPM Plugin System", "Integrates testing into build process")

    Rel(dev, invariant, "Writes tests with @PropertyTest/@BusinessRule")
    Rel(ci, invariant, "Runs via swift test/functest CLI")
    Rel(invariant, swift, "Uses SwiftSyntax macros")
    Rel(invariant, testing, "Generates @Test functions")
    Rel(invariant, spm, "Integrates as plugin")
```

### 3.2 Key Dependencies

| Dependency | Type | Purpose | Criticality |
|------------|------|---------|-------------|
| Swift Compiler (6.0+) | External | Compiles macros, validates concurrency | High |
| SwiftSyntax (509.0.0+) | External | Macro implementation and AST manipulation | High |
| Swift Testing Framework | External | Test execution and assertion integration | High |
| swift-custom-dump (1.3.3+) | External | Pretty printing for test results | Medium |
| Foundation Framework | External | Random number generation, timing utilities | High |
| Darwin/Glibc | External | System-level random entropy | Medium |

### 3.3 Integration Points

- **Upstream**: Swift source code (developers write properties)
- **Downstream**: Swift Testing, test runners, CI/CD systems
- **Synchronous**: Macro expansion (compile-time), property execution (runtime)
- **Asynchronous**: Test result reporting, coverage analysis

---
