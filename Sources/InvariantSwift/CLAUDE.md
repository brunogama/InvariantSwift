# CLAUDE.md - InvariantSwift Main Library

> **Sub-package CLAUDE.md** for `Sources/InvariantSwift/`
>
> Parent: [../../CLAUDE.md](../../CLAUDE.md) | See also: [AGENTS.md](AGENTS.md)

## Package Identity

| Attribute | Value |
|-----------|-------|
| **Purpose** | Core property-based testing library for Swift |
| **Framework** | Pure Swift 6.0 with Sendable conformance |
| **Exports** | `Gen<T>`, `Property`, `Shrink<T>`, `Seed`, `Size`, macros, test runners |
| **Entry Point** | `FunctionalTesting.swift` |

---

## Setup & Commands

### Build & Test

```bash
# Build this package
swift build

# Run all library tests
swift test --filter FunctionalTesting

# Run single test file
swift test --filter "GeneratorTests"

# Typecheck with strict warnings
swift build -Xswiftc -warnings-as-errors
```

### Pre-PR Checklist

```bash
swift build -Xswiftc -warnings-as-errors && \
swift test --filter FunctionalTesting && \
swiftlint lint --strict Sources/InvariantSwift/
```

---

## Directory Structure

```
InvariantSwift/
├── Core/              # Gen, Property, Shrink, Seed, Size (foundational types)
├── Generators/        # String, Int, Collection, Numeric generators
├── Advanced/          # TreeGen, lens, prism, metamorphic testing
├── Faker/             # 100+ fake data generators (ISP-0010)
├── Ghostwriter/       # Auto-test generation (ISP-0009)
├── Fuzzing/           # LibFuzzer integration (ISP-0007)
├── Contract/          # Contract testing (ISP-0006)
├── Differential/      # Differential testing (ISP-0005)
├── Database/          # FailingExampleDatabase (ISP-0004)
├── SwiftTesting/      # Swift Testing integration
├── Testing/           # PropertyRunner, configuration
├── Macros/            # Macro declarations (NOT implementations)
├── Persistence/       # Shrink tree persistence
├── Presentation/      # Pretty-printing, reporters
├── Reliability/       # Flaky test detection
├── Observability/     # Metrics and telemetry
└── FunctionalTesting.swift  # Public API exports
```

---

## Architecture & Patterns

### Core Generator Pattern

```swift
// See: Core/Generator.swift (lines 547-634)
public struct Gen<T>: @unchecked Sendable {
  public let generate: (inout any RandomNumberGenerator, Size) -> T
  public let shrink: Shrink<T>
}
```

### 🌳 ShrinkTree<T> - Canonical Shrinking Model

The library standardizes on `ShrinkTree<T>` for deterministic, BFS-based shrinking:

```swift
// See: Core/ShrinkTree.swift
public struct ShrinkTree<T>: @unchecked Sendable {
  public let value: T
  public var children: [ShrinkTree<T>]  // Lazy evaluation

  // Find minimal value satisfying predicate via BFS
  public func findMinimal(budget: Int, satisfying: (T) -> Bool) -> T?

  // Performance controls
  public func limitBreadth(_ maxChildren: Int) -> ShrinkTree<T>
  public func limitTotal(_ maxNodes: Int) -> ShrinkTree<T>
  public func prune(maxDepth: Int) -> ShrinkTree<T>
}

// Bridge from legacy Shrink<T> to tree-based search
let tree = ShrinkTree.from(100, shrink: Shrink<Int> { ... })
```

**Key advantages:**
- **Deterministic**: Same seed → same shrink path (reproducible failures)
- **BFS search**: Finds truly minimal counterexamples (not greedy-first)
- **Lazy evaluation**: Children computed on-demand (memory efficient)
- **Composable**: `map`, `flatMap`, `filter` for complex shrinking

**Deprecated types** (migrate to ShrinkTree):
- `Node<A>` (was in Advanced/ShrinkTrees.swift) → use `ShrinkTree<T>`
- `TreeGen<A>` (was in Advanced/ShrinkTrees.swift) → use `Gen<T>` with standard shrinking

See [docs/SHRINKING_MIGRATION.md](../../docs/SHRINKING_MIGRATION.md) for detailed migration guide.

### ✅ DO: Use Gen Combinators

```swift
// See: Generators/StringGenerator.swift
Gen<String>.faker(.email)                    // Fake email
Gen<Int>.pure(42)                            // Constant value
Gen.oneOf([gen1, gen2])                      // Random choice
Gen.zip(genA, genB).map { "\($0):\($1)" }   // Combine generators
Gen.array(Gen<Int>.int, count: 1...10)       // Array of 1-10 ints
```

### ✅ DO: Implement Shrink Strategies

```swift
// See: Core/Generator.swift (lines 95-512)
Shrink<Int> { n in Shrink.towards(0, n) }
Shrink.removeElements(from: array)
Shrink.halveContinuous(value)
```

**PropertyRunner automatically converts `Shrink<T>` to `ShrinkTree<T>` via `ShrinkTree.from()` and uses BFS search to find minimal counterexamples.**

### ✅ DO: Property Test Pattern

```swift
// See: Testing/PropertyRunner.swift
let property = Property(generator: Gen<Int>.int) { value in
  value + 0 == value  // Identity property
}
try await checkProperty(property)

// PropertyRunner automatically:
// 1. Generates values with the generator
// 2. Shrinks failures using ShrinkTree + BFS
// 3. Respects assumptions via filter()
// 4. Limits search with maxShrinks budget
```

### ❌ DON'T: Use Force Unwrap

```swift
// BAD - Never do this
let value = optional!

// GOOD - Use guard
guard let value = optional else { return }
```

### ❌ DON'T: Use fatalError in Library Code

```swift
// BAD - Crashes users' code
fatalError("Invalid state")

// GOOD - Make illegal states unrepresentable
enum State { case valid(Data) }  // No invalid case possible
```

---

## Key Files (Touch Points)

| File | Purpose | Lines |
|------|---------|-------|
| `Core/Generator.swift` | `Gen<T>`, `Shrink<T>`, `Size`, `Seed` | ~600 |
| `Core/Property.swift` | Property test definition | ~200 |
| `Testing/PropertyRunner.swift` | Test execution engine | ~400 |
| `Generators/StringGenerator.swift` | String generators | ~150 |
| `Faker/FakerGenerator.swift` | 100+ fake data generators | ~500 |
| `Faker/FakerType.swift` | Faker type enumeration | ~200 |
| `Ghostwriter/Ghostwriter.swift` | Auto-test generation | ~300 |
| `FunctionalTesting.swift` | Public API exports | ~100 |

---

## Quick Find Commands (JIT Index)

### Find Generators

```bash
# Find all generator definitions
rg -n "public static (func|var)" Generators/ Core/

# Find Faker types
rg -n "case \." Faker/FakerType.swift

# Find shrink implementations
rg -n "Shrink\(" Core/Generator.swift
```

### Find Property Patterns

```bash
# Find property test patterns
rg -n "@PropertyTest|checkProperty" .

# Find all public API
rg -n "^public " --type swift

# Find async functions
rg -n "async func|async throws" .
```

### Find Specific Features

```bash
# Ghostwriter
rg -n "Ghostwriter|ghostwrite" Ghostwriter/

# LibFuzzer integration
rg -n "FuzzDataProvider|fuzz" Fuzzing/

# Lens/Prism optics
rg -n "Lens|Prism|Traversal" Advanced/
```

---

## Common Gotchas

1. **Sendable conformance**: Use `@unchecked Sendable` because closures capture mutable RNG
2. **Size parameter**: Always pass through `Size` for recursive generators to prevent infinite depth
3. **Shrink termination**: Ensure shrink functions eventually return `[]` to prevent infinite loops
4. **Determinism**: Same `Seed` + `Size` must always produce same value (critical for reproducibility)
5. **ShrinkTree vs Shrink**: Don't use deprecated `Node<A>` or `TreeGen<A>`. Use `ShrinkTree<T>` directly or let PropertyRunner convert via `ShrinkTree.from()`
6. **BFS search budget**: Set `maxShrinks` in PropertyConfig to control shrinking complexity (default: 1000)
7. **Macro declarations vs implementations**: This directory has declarations only; implementations are in `InvariantSwiftMacros/`

---

## Testing This Package

```bash
# Run all tests
swift test --filter FunctionalTesting

# Run specific test suite
swift test --filter GeneratorTests

# Run with coverage
swift test --filter FunctionalTesting --enable-code-coverage
```

---

## Related Documents

- [AGENTS.md](AGENTS.md) - General AI agent conventions for this directory
- [../../CLAUDE.md](../../CLAUDE.md) - Root project guidance
- [docs/GENERATORS.md](../../docs/GENERATORS.md) - Generator documentation
- [docs/COOKBOOK.md](../../docs/COOKBOOK.md) - Usage patterns
