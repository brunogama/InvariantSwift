# Decision Log

### ADR-001: Protocol-Witness Architecture

- **Status**: Accepted
- **Date**: January 2024
- **Context**: Need for composable, type-safe generator abstractions aligned with functional programming
- **Decision**: Use protocol-witness pattern for Generator trait with associated types and function witnesses
- **Consequences**: Enables category theory abstractions (functor, applicative, monad), no inheritance overhead, aligns with Swift idioms

### ADR-002: SwiftSyntax Macros Over Runtime Reflection

- **Status**: Accepted
- **Date**: January 2024
- **Context**: Need for developer-friendly API without runtime reflection overhead
- **Decision**: Use SwiftCompilerPlugin with SwiftSyntax for @PropertyTest and @BusinessRule macros
- **Consequences**: Compile-time code generation, zero runtime cost, IDE integration, requires Swift 5.9+, steeper learning curve for maintainers

### ADR-003: Actor-Based Concurrency for Runner

- **Status**: Accepted
- **Date**: June 2024
- **Context**: Swift 6 strict concurrency enforcement requires thread-safe test execution
- **Decision**: Implement PropertyRunner as actor with async/await interface
- **Consequences**: Type-safe concurrent property testing, prevents race conditions, requires `await` at call sites, aligns with Swift 6 concurrency model

### ADR-004: Tree-Based Shrinking Strategy

- **Status**: Accepted
- **Date**: January 2024
- **Context**: Need for efficient minimal counterexample discovery
- **Decision**: Implement shrinking via lazy tree traversal with cached predicate results
- **Consequences**: Deterministic shrinking, efficient for most types, bounded by maxShrinks, simpler than SAT-based approaches

### ADR-005: Coverage-Guided Generation via Heuristics

- **Status**: Accepted
- **Date**: June 2024
- **Context**: Need for 99%+ coverage without runtime instrumentation
- **Decision**: Implement coverage mapping with heuristic-based bias toward uncovered code paths
- **Consequences**: No instrumentation overhead, practical coverage guidance, less precise than symbolic execution, heuristics tuned empirically

### ADR-006: Package Rename to InvariantSwift

- **Status**: Accepted
- **Date**: January 2026
- **Context**: Rebranding from FunctionalTesting to better represent advanced features and mathematical rigor
- **Decision**: Complete migration of all package targets, module names, and public APIs to InvariantSwift
- **Consequences**: Breaking change for 1.x users (major version bump), clearer domain representation, aligns with mathematical terminology

---
