# High-Level Architecture

### 4.1 Architecture Style

**Layered (Presentation → Business → Data → Infrastructure)**

**Rationale**:
- Clear separation of concerns aligns with testing framework structure
- Generators (data layer) are independent of properties (business logic)
- Macros (presentation) abstract away low-level APIs
- Testing strategy enables comprehensive component testing at each layer

### 4.2 Component Overview

```mermaid
graph TB
    subgraph "Presentation Layer (Macros)"
        PT["@PropertyTest Macro"]
        BR["@BusinessRule Macro"]
        LM["Mathematical Law Macros"]
    end

    subgraph "Core Testing Layer"
        PR["Property<T>"]
        PC["PropertyConfig"]
        RN["PropertyRunner"]
    end

    subgraph "Generator Layer"
        GEN["Gen<T>"]
        PRIM["Primitive Generators"]
        COLL["Collection Generators"]
        COMB["Combinator Generators"]
    end

    subgraph "Advanced Features Layer"
        CG["Coverage-Guided Testing"]
        MB["Model-Based Testing"]
        LS["Lens System"]
        ASYNC["Async Properties"]
        LINEAR["Linearizability Testing"]
    end

    subgraph "Infrastructure Layer"
        SEED["Seed Management"]
        RNG["RandomNumberGenerator"]
        SHRINK["Shrinking Trees"]
        TEL["Telemetry System"]
    end

    PT --> PR
    BR --> PR
    LM --> PR
    PR --> GEN
    PR --> RN
    RN --> CG
    RN --> MB
    RN --> ASYNC
    GEN --> PRIM
    GEN --> COLL
    GEN --> COMB
    COMB --> LS
    COMB --> LINEAR
    PR --> SEED
    GEN --> RNG
    RN --> SHRINK
    RN --> TEL
```

### 4.3 Key Design Decisions

| Decision | Options Considered | Choice | Rationale |
|----------|-------------------|--------|-----------|
| **Macro System** | Compile-time codegen vs runtime reflection | SwiftSyntax macros | Compile-time safety, zero runtime overhead, IDE integration |
| **Generic Architecture** | Protocol-witness vs class hierarchy vs enum | Protocol-witness with associated types | Aligns with Swift idioms, enables category theory abstractions |
| **Shrinking Algorithm** | Genetic algorithms vs tree traversal vs SAT solvers | Tree-based shrinking with bias | Deterministic, composable, efficient for most types |
| **Concurrency Model** | Thread-based vs actor-based vs async/await only | Actor-based with async/await | Swift 6 compliance, type-safe concurrent testing |
| **Coverage Guidance** | Instrumentation vs symbolic execution vs heuristic | Heuristic-based coverage mapping | No runtime instrumentation needed, practical for frameworks |
| **Generator Composition** | Inheritance vs composition vs protocol defaults | Protocol composition with default implementations | Functional style, enables lens abstractions |

### 4.4 Data Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Macro as @PropertyTest Macro
    participant Gen as Generator
    participant Prop as Property<T>
    participant Runner as PropertyRunner
    participant Shrink as Shrinker
    participant Report as Report

    Dev->>Macro: Write @PropertyTest func
    Macro->>Gen: Generate random inputs
    Gen-->>Macro: [value1, value2, ...]
    Macro->>Prop: Create Property with predicate
    Prop->>Runner: Run property test
    Runner->>Gen: Generate test case
    Gen-->>Runner: Random value
    Runner->>Prop: Execute predicate
    alt Property Passes
        Prop-->>Runner: true
    else Property Fails
        Prop-->>Runner: false
        Runner->>Shrink: Minimize counterexample
        Shrink-->>Runner: Shrunk value
    end
    Runner-->>Report: PropertyResult
    Report-->>Dev: Test result summary
```

---
